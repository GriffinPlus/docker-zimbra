"""
This module contains everything needed to configure 'Zimbra'.
Author: Sascha Falk <sascha@falk-online.eu>
License: MIT License
"""

import os
import re

from ..cc_log import Log
from ..cc_cmdproc import CommandProcessor, PositionalArgument, NamedArgument
from ..cc_errors import GeneralError, CommandLineArgumentError, FileNotFoundError, IoError, ConfigurationError, EXIT_CODE_SUCCESS
from ..cc_helpers import read_text_file, write_text_file, replace_php_define, replace_php_variable, generate_password, get_env_setting_bool, get_env_setting_integer, get_env_setting_string


# -------------------------------------------------------------------------------------------------------------------------------------------------------------


# name of the processor
processor_name = 'zimbra'

# determines whether the processor is run by the startup script
enabled = True

def get_processor():
    "Returns an instance of the processor provided by the command processor plugin."
    return ZimbraCommandProcessor()


# -------------------------------------------------------------------------------------------------------------------------------------------------------------


class ZimbraCommandProcessor(CommandProcessor):

    # -------------------------------------------------------------------------------------------------------------------------------------

    def __init__(self):

        # let base class perform its initialization
        super().__init__()

        # register command handlers
        self.add_handler(self.run, PositionalArgument("run"))
        self.add_handler(self.run, PositionalArgument("run-and-enter"))


    # -------------------------------------------------------------------------------------------------------------------------------------


    def run(self, pos_args, named_args):

        return EXIT_CODE_SUCCESS


    # -------------------------------------------------------------------------------------------------------------------------------------
