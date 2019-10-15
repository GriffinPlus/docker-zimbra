#!/usr/bin/env python3

import signal
import os
import shutil
import pem
import urllib.request
import sys
import time
import datetime

from pwd import getpwnam
from subprocess import call
from OpenSSL import crypto
from stat import S_IRUSR, S_IWUSR, S_IRGRP, S_IWGRP, S_IROTH, S_IWOTH
from tempfile import TemporaryDirectory

from cryptography import x509
from cryptography.hazmat.backends import default_backend
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.asymmetric import rsa, ec
from cryptography.hazmat.primitives.serialization import Encoding, PrivateFormat, BestAvailableEncryption, NoEncryption, load_pem_private_key, load_der_private_key
from cryptography.x509.oid import NameOID, ExtensionOID, AuthorityInformationAccessOID


# ---------------------------------------------------------------------------------------------------------------------


SCRIPT_DIR = os.path.dirname(os.path.realpath(__file__))
TLS_DIR_PATH = SCRIPT_DIR + "/tls"
TLS_KEY_FILE_PATH_DEFAULT = TLS_DIR_PATH + "/zimbra.key"
TLS_CRT_FILE_PATH_DEFAULT = TLS_DIR_PATH + "/zimbra.crt"
ZIMBRA_USER = "zimbra"
ZIMBRA_PRIVATE_KEY_PATH = "/opt/zimbra/ssl/zimbra/commercial/commercial.key"


# ---------------------------------------------------------------------------------------------------------------------


LOG_LEVEL = 3   # all (0), error(1), warning(2), note(3), debug(4)

def log_error(text):
    if LOG_LEVEL >= 1:
        print("{0} : {1}".format(datetime.datetime.now().isoformat(), text))

def log_warning(text):
    if LOG_LEVEL >= 2:
        print("{0} : {1}".format(datetime.datetime.now().isoformat(), text))

def log_note(text):
    if LOG_LEVEL >= 3:
        print("{0} : {1}".format(datetime.datetime.now().isoformat(), text))

def log_debug(text):
    if LOG_LEVEL >= 4:
        print("{0} : {1}".format(datetime.datetime.now().isoformat(), text))


# ---------------------------------------------------------------------------------------------------------------------


def load_certificate_file(path):
    """
    Loads the certificate(s) in the specified file (can be DER/PEM encoded or a PKCS7 bundle).

    Args:
        path (str) : Path of the certificate file to load.

    Returns:
        A list with the loaded certificates.

    """
    with open(path, 'rb') as f:
        data = f.read()

    try:
        return decode_certificate_data(data)
    except ValueError as e:
        raise ValueError("Decoding certificate file ({0}) failed: {1}".format(path, e))


# ---------------------------------------------------------------------------------------------------------------------


def decode_certificate_data(data):
    """
    Decodes a blob containing encoded X.509 certificates (can be DER/PEM encoded or a PKCS7 bundle).

    Args:
        data (bytes) : Buffer containing the encoded certificate(s).

    Returns:
        A list with cryptography X.509 certificates (not OpenSSL X.509 certificates!)

    """

    # PEM encoded?
    try:
        # try to decode the first certificate directly (fails, if not PEM encoded)
        x509.load_pem_x509_certificate(data, default_backend())
        # ok, it's PEM encoded... but it may contain multiple certificates, try to unpack!
        certificates = [ x509.load_pem_x509_certificate(x.as_bytes(), default_backend()) for x in pem.parse(data) ]
        log_debug("Successfully decoded {0} PEM encoded certificate(s):".format(len(certificates)))
        for x in certificates: log_debug("- subject: {0}".format(x.subject))
        return certificates
    except ValueError:
        pass

    # DER encoded?
    try:
        certificate = x509.load_der_x509_certificate(data, default_backend())
        log_debug("Successfully decoded a DER encoded certificate:")
        log_debug("- subject: {0}".format(certificate.subject))
        return [ certificate ]
    except ValueError:
        pass

    # PKCS7, PEM encoded
    try:
        pkcs7 = crypto.load_pkcs7_data(crypto.FILETYPE_PEM, data)
        certificates = get_pkcs7_certificates(pkcs7)
        log_debug("Successfully decoded PEM encoded PKCS#7 bundle, extracted {0} certificate(s):".format(len(certificates)))
        for x in certificates: log_debug("- subject: {0}".format(x.subject))
        return list(certificates)
    except crypto.Error:
        pass

    # PKCS7, DER encoded
    try:
        pkcs7 = crypto.load_pkcs7_data(crypto.FILETYPE_ASN1, data)
        certificates = get_pkcs7_certificates(pkcs7)
        log_debug("Successfully decoded DER encoded PKCS#7 bundle, extracted {0} certificate(s):".format(len(certificates)))
        for x in certificates: log_debug("- subject: {0}".format(x.subject))
        return list(certificates)
    except crypto.Error:
        pass

    raise ValueError("Decoding certificates failed.")


# ---------------------------------------------------------------------------------------------------------------------


def get_pkcs7_certificates(bundle):
    """
    Extracts X.509 certificates from an OpenSSL PKCS7 object.

    Args:
        bundle (OpenSSL PKCS7 object) : PKCS7 object to extract the certificates from.

    Returns:
        A tuple containing the extracted certificates
        (cryptography X.509 certificates, not OpenSSL X.509 certificates!)

    """
    from OpenSSL._util import (
        ffi as _ffi,
        lib as _lib
    )
    from OpenSSL.crypto import X509

    pkcs7_certs = _ffi.NULL
    if bundle.type_is_signed():
        pkcs7_certs = bundle._pkcs7.d.sign.cert
    elif bundle.type_is_signedAndEnveloped():
        pkcs7_certs = bundle._pkcs7.d.signed_and_enveloped.cert

    certificates = []
    for i in range(_lib.sk_X509_num(pkcs7_certs)):
        certificate = X509.__new__(X509)
        certificate._x509 = _ffi.gc(_lib.X509_dup(_lib.sk_X509_value(pkcs7_certs, i)), _lib.X509_free)
        certificates.append(certificate.to_cryptography())
    if not certificates:
        return tuple()
    return tuple(certificates)


# ---------------------------------------------------------------------------------------------------------------------


def load_private_key_file(path):
    """
    Loads the private key from the specified file (can be DER or PEM encoded).

    Args:
        path (str) : Path of the private key file to load.

    Returns:
        The loaded private key (cryptography private key, not OpenSSL private key!)

    """
    with open(path, 'rb') as f:
        data = f.read()

    try:
        key = load_pem_private_key(data, None, default_backend())
        log_debug("Successfully loaded PEM encoded private key from {0}.".format(path))
        return key
    except ValueError:
        pass

    try:
        key = load_der_private_key(data, None, default_backend())
        log_debug("Successfully loaded DER encoded private key from {0}.".format(path))
        return key
    except ValueError:
        pass

    raise ValueError("The private key file was loaded successfully, but it does not seem to be a PEM/DER encoded private key.")


# ---------------------------------------------------------------------------------------------------------------------


def fix_certificate_chain(certificates):
    """
    Checks the specified certificates and adds missing CA certificates, if necessary.

    Args:
        certificates (list of cryptography X.509 certificates) : The certificates to check and fix.

    Returns:
        The fixed certificate chain (cryptography X.509 certificates, not OpenSSL X.509 certificates!).

    """

    certificates = certificates[:]
    current_certificate = certificates[0]
    fixed_certificate_chain = [ current_certificate ]

    while True:

        for certificate in certificates:
            if current_certificate.issuer == certificate.subject:
                fixed_certificate_chain.append(certificate)
                current_certificate = certificate
                break

        if current_certificate != certificate:
            continue # found issuer certificate in the chain, proceed with the next one...

        # abort at the root of the chain
        if current_certificate.subject == current_certificate.issuer:
            break;

        try_again = False

        try:
            extension = current_certificate.extensions.get_extension_for_oid(ExtensionOID.AUTHORITY_INFORMATION_ACCESS)
            for x in extension.value:
                if x.access_method == AuthorityInformationAccessOID.CA_ISSUERS:
                    certificate_url = x.access_location.value;
                    log_debug("Downloading CA certificate from {0}.".format(certificate_url))
                    with urllib.request.urlopen(certificate_url) as response:
                        ca_certificates = decode_certificate_data(response.read())
                    if not ca_certificates or ca_certificates[0].subject != current_certificate.issuer:
                        log_error("The downloaded certificate ({0}) is not the expected certificate.".format(certificate_url))
                        raise RuntimeError("The downloaded CA certificate ({0}) is not the expected certificate.".format(certificate_url))

                    # add downloaded certificate(s) to the collection and try to resolve the chain once again
                    certificates.extend(ca_certificates)
                    try_again = True
                    log_debug("Added downloaded CA certificates to the certificate collection, trying again...")
                    break;
        except x509.ExtensionNotFound:
            log_debug("The 'Authority Information Access' extension was not found on the certificate.")
            pass

        if try_again: continue
        else:         break

    return fixed_certificate_chain


# ---------------------------------------------------------------------------------------------------------------------


class CertificateChainError(Exception):
    """
    Exception that is raised, if a certificate chain is invalid.

    """

    def __init__(self, message, *args):
        self.message = message.format(*args)


def verify_certificate_chain(certificates):
    """
    Verifys the the specified certificate chain.

    Args:
        certificates (list of cryptography X.509 certificates) : Certificate chain to verify.
    """
    try:
        store = crypto.X509Store()
        for certificate in certificates[1:]: store.add_cert(crypto.X509.from_cryptography(certificate))
        store_ctx = crypto.X509StoreContext(store, crypto.X509.from_cryptography(certificates[0]))
        store_ctx.verify_certificate()
    except Exception as e:
        log_debug("Verifying certificate chain failed: {0}".format(e))
        raise CertificateChainError("Verifying certificate chain failed.")


# ---------------------------------------------------------------------------------------------------------------------


def configure_zimbra(server_key, server_certificate, ca_certificate_chain):
    """
    Updates the private key and certificates in Zimbra.

    """

    user = getpwnam(ZIMBRA_USER)

    with TemporaryDirectory() as temp_dir_path:

        # write server certificate
        server_certificate_path = temp_dir_path + "/server.crt"
        with open(server_certificate_path, "wb") as f:
            f.write(server_certificate.public_bytes(Encoding.PEM))
        os.chown(server_certificate_path, user.pw_uid, user.pw_gid)
        os.chmod(server_certificate_path, S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH)

        # write ca certificate chain
        certificate_chain_path = temp_dir_path + "/chain.crt"
        with open(certificate_chain_path, "wb") as f:
            for certificate in ca_certificate_chain:
                f.write(certificate.public_bytes(Encoding.PEM))
        os.chown(certificate_chain_path, user.pw_uid, user.pw_gid)
        os.chmod(certificate_chain_path, S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH)

        # write private key
        private_key_path = temp_dir_path + "/server.key"
        with open(private_key_path, "wb") as f:
            f.write(server_key.private_bytes(
                encoding = Encoding.PEM,
                format = PrivateFormat.TraditionalOpenSSL,
                encryption_algorithm = NoEncryption()))
        os.chown(private_key_path, user.pw_uid, user.pw_gid)
        os.chmod(private_key_path, S_IRUSR | S_IWUSR)

        # give zimbra user access to the temporary directory
        os.chown(temp_dir_path, user.pw_uid, user.pw_gid)

        # configure zimbra to use the certificate
        shutil.copy2(private_key_path, ZIMBRA_PRIVATE_KEY_PATH)
        call( [ "sudo", "-u", "zimbra", "/opt/zimbra/bin/zmcertmgr", "deploycrt", "comm", server_certificate_path, certificate_chain_path ] )
        call( [ "sudo", "-u", "zimbra", "/opt/zimbra/bin/zmcontrol", "restart" ] )


# ---------------------------------------------------------------------------------------------------------------------
# - MAIN --------------------------------------------------------------------------------------------------------------
# ---------------------------------------------------------------------------------------------------------------------


# set up signal handling
# ---------------------------------------------------------------------------------------------------------------------

def signal_handler(signal, frame):
    global interrupted
    interrupted = True

signal.signal(signal.SIGTERM, signal_handler)
signal.signal(signal.SIGINT, signal_handler)

# worker
# ---------------------------------------------------------------------------------------------------------------------

tls_crt_file_path = os.getenv('TLS_CRT_FILE_PATH', TLS_CRT_FILE_PATH_DEFAULT)
tls_key_file_path = os.getenv('TLS_KEY_FILE_PATH', TLS_KEY_FILE_PATH_DEFAULT)

interrupted = False
last_certificates = None
while not interrupted:

    try:

        # load certificates
        certificates = load_certificate_file(tls_crt_file_path)

        if certificates != last_certificates:

            log_note("Certificate file has changed. Starting update...")


            # load private key
            log_note("Loading private key ({0})...".format(tls_key_file_path))
            server_private_key = load_private_key_file(tls_key_file_path)

            # append missing CA certificates, if necessary
            log_note("Checking certificate chain, fixing if necessary...")
            fixed_certificates = fix_certificate_chain(certificates)
            server_certificate = fixed_certificates[0]
            ca_certificate_chain = fixed_certificates[1:]

            # verify certificate chain
            log_note("Verifying the created certificate chain...")
            verify_certificate_chain(fixed_certificates)
            log_note("The certificate chain is valid.")

            # update certificates in Zimbra
            log_note("Configuring Zimbra...")
            configure_zimbra(server_private_key, server_certificate, ca_certificate_chain)

            # everything is fine => running again is not necessary
            log_note("Certificates were updated successfully.")
            last_certificates = certificates

    except Exception as e:
        log_error(e)
        pass

    except:
        log_error("Unexpected error: {0}".format(sys.exc_info()[0]))
        pass

    # run only this turn, if requested
    if len(sys.argv) >= 2 and sys.argv[1] == 'once':
        interrupted = True

    # wait some time and try again...
    if not interrupted:
        time.sleep(10)

