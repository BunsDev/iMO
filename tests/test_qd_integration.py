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
        auction_end = self.get_auction_end()
        print(f'auction_end = {auction_end}')
        print(f'chain.time() = {chain.time()}')
        if chain.time() >= auction_end:
            print('AUCTION is over; should revert.')
            with brownie.reverts('QD: MINT_R2'):
                self.qd.mint(qd_amount, self.from_bob)
            return

        print(f'qd_amount = {qd_amount}')
        usdt_needed = self.qd.qd_amount_to_usdt_amount(qd_amount, chain.time())
        self.usdt.unprotectedMint(self.bob, usdt_needed)
        self.usdt.approve(self.qd.address, usdt_needed, self.from_bob)

        time_elapsed = chain.time() - self.qd.auction_start()
        qd_total_supply = self.qd.totalSupply()
        print(f'time_elapsed = {time_elapsed}')
        print(f'qd_total_supply = {qd_total_supply}')

        arithmetic_diff = qd_amount + qd_total_supply - 514_285 * 10 ** 24 * time_elapsed // (24 * 60 * 60)

        print(f'arithmetic_diff = {arithmetic_diff}')

        total_supply_cap = self.qd.get_total_supply_cap()
        print(f'total_supply_cap = {total_supply_cap}')

        if arithmetic_diff > 10:
            with brownie.reverts('QD: MINT_R3'):
                self.qd.mint(qd_amount, self.from_bob)
        elif arithmetic_diff < - 10:
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
        
    def get_auction_end(self) -> int:
        auction_start  = self.qd.auction_start()
        auction_length = self.qd.AUCTION_LENGTH()
        auction_end    = auction_start + auction_length
        return auction_end
        

# We can only pass external data to StateMachine in this function
def test_state_machines(
    state_machine,
    accounts,
    TestERC20,
    QD,
):
    state_machine(StateMachineQdIntegration, accounts, TestERC20, QD)