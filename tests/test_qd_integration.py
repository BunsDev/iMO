# for debugging logs
import inspect

import brownie
from brownie import *
from brownie.test import given, strategy
from hypothesis import settings, event

from tests.common import get_params, DAY, WEEK

class StateMachineQdIntegration:
    st_uint = strategy('uint256')

    def __init__(cls, acs, Test_Erc20, Qd):
        print(f'StateMachineQdIntegration.__init__')

        # Accounts
        cls.acs      = acs
        cls.alice    = acs[0]
        cls.bob      = acs[1]
        cls.charlie  = acs[2]
        cls.from_bob = {'from': cls.bob}
        acs.default  = cls.alice
        
        # Contracts
        cls.usdt = Test_Erc20.deploy()
        cls.qd   = Qd.deploy(cls.usdt.address)

    
    def rule_mint(self, st_uint):
        print(f'{inspect.currentframe().f_code.co_name} called with params:')
        print(get_params(locals()))
        qd_balance_bob_initial = self.qd.balanceOf(self.bob)
        qd_amount = max(10 ** 24, st_uint % 10 ** 30) # up to 1M QD, but at least 1 QD
        usdt_needed = self.qd.qd_amount_to_usdt_amount(qd_amount, chain.time())
        self.usdt.unprotectedMint(self.bob, usdt_needed)
        self.usdt.approve(self.qd.address, usdt_needed, self.from_bob)
        self.qd.mint(qd_amount, self.from_bob)
        qd_balance_bob_final = self.qd.balanceOf(self.bob)
        assert qd_balance_bob_initial + qd_amount == qd_balance_bob_final
    
    def rule_advance_time(self, st_uint):
        print(f'{inspect.currentframe().f_code.co_name} called with params:')
        print(get_params(locals()))
        # sleep 
        chain.sleep(20 * 24 * 60 * 60)    
                
    def rule_withdraw(self, st_uint):
        print(f'{inspect.currentframe().f_code.co_name} called with params:')
        print(get_params(locals()))
        # owner (alice) can withdraw
        balance_usdt_initial = self.usdt.balanceOf(self.qd.address)
        to_withdraw = st_uint % balance_usdt_initial if balance_usdt_initial else 0
        self.qd.withdraw(to_withdraw)
        balance_usdt_final = self.usdt.balanceOf(self.qd.address)
        assert balance_usdt_initial - to_withdraw == balance_usdt_final
        

# We can only pass external data to StateMachine in this function
def test_state_machines(
    state_machine,
    accounts,
    TestERC20,
    QD,
):
    state_machine(StateMachineQdIntegration, accounts, TestERC20, QD)