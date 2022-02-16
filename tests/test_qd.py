# for debugging logs
import inspect

import brownie
from brownie import *
from brownie.test import given, strategy
from hypothesis import settings, event

from tests.common import get_params, DAY, WEEK

class StateMachineQd:
    st_uint = strategy('uint256')

    def __init__(cls, acs, Test_Erc20, Qd):
        cls.acs = acs
        acs.default = acs[0]
        cls.test_erc20 = Test_Erc20.deploy()
        cls.qd = Qd.deploy(cls.test_erc20.address, acs[0])

            
    def rule_decimals(self):
        # print function name
        print(f'{inspect.currentframe().f_code.co_name} called with params:') # sol-env: debug
        # print parameters
        print(get_params(locals())) # sol-env: debug
        assert self.qd.decimals() == 24

# We can only pass external data to StateMachine in this function
def test_state_machines(
    state_machine,
    accounts,
    TestERC20,
    QD,
):
    state_machine(StateMachineQd, accounts, TestERC20, QD)