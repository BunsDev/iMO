# for debugging logs
import inspect
import functools

import brownie
from brownie import *
from brownie.test import given, strategy
from hypothesis import settings, event

from tests.common import get_params, DAY, WEEK

class StateMachineQdUnit:
    st_uint = strategy('uint256')

    def __init__(cls, acs, Test_Erc20, Qd):
        print(f'StateMachineQdUnit.__init__')
        
        cls.acs = acs
        acs.default = acs[0]
        cls.usdt = Test_Erc20.deploy()
        cls.qd = Qd.deploy(cls.usdt.address)

    def rule_decimals(self):
        print(f'{inspect.currentframe().f_code.co_name} called with params:')
        print(get_params(locals()))
        assert self.qd.decimals() == 24

    # region: qd_amount_to_usdt_amount
    
    def rule_init_price(self, st_uint):
        print(f'{inspect.currentframe().f_code.co_name} called with params:')
        print(get_params(locals()))
        auction_start = self.qd.auction_start()
        res = self.qd.qd_amount_to_usdt_amount(st_uint, auction_start)
        assert res == st_uint // 10 ** 18 * 12 // 100
        
        
    def rule_final_price(self, st_uint):
        print(f'{inspect.currentframe().f_code.co_name} called with params:')
        print(get_params(locals()))
        auction_end = self.get_auction_end()

        res = self.qd.qd_amount_to_usdt_amount(st_uint, auction_end - 1)
        assert res == st_uint // 10 ** 18 * 94 // 100
    
    def rule_qd_amount_to_usdt_amount(self, st_uint):
        print(f'{inspect.currentframe().f_code.co_name} called with params:')
        print(get_params(locals()))
        auction_start  = self.qd.auction_start()
        auction_length = self.qd.AUCTION_LENGTH()
        
        random_time_elapsed = st_uint % auction_length
        
        res = self.qd.qd_amount_to_usdt_amount(st_uint, auction_start + random_time_elapsed)
        price =  (chain.time() - auction_start) // auction_length * (94 - 12) + 12
        assert res == st_uint * price / 10 ** 18 / 100
    
    def get_auction_end(self) -> int:
        auction_start  = self.qd.auction_start()
        auction_length = self.qd.AUCTION_LENGTH()
        auction_end    = auction_start + auction_length
        return auction_end
        
    # endregion

# We can only pass external data to StateMachine in this function
def test_state_machines(
    state_machine,
    accounts,
    TestERC20,
    QD,
):
    state_machine(StateMachineQdUnit, accounts, TestERC20, QD)