from typing import Union
import random
from brownie import *
import brownie

from contract_types import *
from tests.helpers import off_by_atmost_1
from tests.constants import *
from tests.fixtures import *
from tests.helpers import *

def test_mint_below_100(qd: QDType, alice, from_alice):
    amount = random.randint(0, 100 * int(QD_PRECISION) - 1)
    with brownie.reverts('QD: MINT_R1'):
        qd.mint(amount, alice, from_alice)

def test_mint_before_sale_start(qd: QDType, alice, from_alice):
    amount = 100 * int(QD_PRECISION)
    current_time = chain.time()
    if current_time < START:
        with brownie.reverts('QD: MINT_R2'):
            qd.mint(amount, alice, from_alice)

def test_mint_after_sale_end(qd: QDType, alice, from_alice):
    amount = 100 * int(QD_PRECISION)
    current_time = chain.time()
    chain.sleep(END - current_time)
    with brownie.reverts('QD: MINT_R2'):
        qd.mint(amount, alice, from_alice)
        
def execute_mint_from_owner(
    qd: QDType,
    usdt: TestERC20Type,
    owner: Account,
    cost: Union[int, Decimal],
):
    owner_qd_bal      = qd.balanceOf(owner)
    qd_usdt_bal       = usdt.balanceOf(qd)
    private_deposited = qd.private_deposited()
    public_deposited  = qd.public_deposited()
    ua_usdt_bal       = usdt.balanceOf(UA)
    
    amount = int(Decimal('2.7e30'))
    usdt.unprotectedMint(owner, cost)
    usdt.approve(qd, cost)
    qd.mint(amount, owner)
    assert usdt.balanceOf(owner)  == 0
    assert usdt.balanceOf(qd)     == qd_usdt_bal + cost
    assert qd.balanceOf(owner)    == owner_qd_bal + amount
    assert qd.private_deposited() == private_deposited + cost
    assert qd.public_deposited()  == public_deposited
    assert usdt.balanceOf(UA)     == ua_usdt_bal

def test_mint_from_owner(
    qd: QDType,
    usdt: TestERC20Type,
    owner: Account,
    from_owner: TxnConfig,
    count: int = 1,
):
    current_time = chain.time()
    chain.sleep(START - current_time)
    
    first_time_cost   = Decimal('1.62e11')
    marginal_cost_inc = Decimal('5.4e10')

    execute_mint_from_owner(
        qd = qd,
        usdt = usdt,
        owner = owner,
        cost = first_time_cost + marginal_cost_inc * (2 * count - 2)
    )
    
    execute_mint_from_owner(
        qd = qd,
        usdt = usdt,
        owner = owner,
        cost = first_time_cost + marginal_cost_inc * (2 * count - 1)
    )

def test_mint_over_supply_cap(
    qd: QDType,
    alice: Account,
    from_alice: TxnConfig,
):
    current_time = chain.time()
    time_elapsed = random.randint(START - current_time, END - current_time)
    chain.sleep(time_elapsed)

    # QD can distribute up to 5 QD per second
    # Add 10 here just in case ganache increments block.timestamp
    amount = qd.get_total_supply_cap(current_time + time_elapsed + 1) - qd.totalSupply() \
        + 10 + 2 * Decimal('2.7e30')

    with brownie.reverts('QD: MINT_R3'):
        qd.mint(amount, alice, from_alice)

def test_mint_from_alice(
    qd: QDType,
    usdt: TestERC20Type,
    alice: Account,
    from_alice: TxnConfig,
):
    alice_qd_bal = qd.balanceOf(alice)
    qd_public_deposited = qd.public_deposited()
    private_deposited = qd.private_deposited()
    qd_usdt_bal = usdt.balanceOf(qd)
    ua_usdt_bal = usdt.balanceOf(UA)

    if (current_time := chain.time()) < START:
        time_elapsed = random.randint(START - current_time, END - current_time)
        chain.sleep(time_elapsed)

    # It seems to be difficult to control ganache time reliably
    # From the documentation, it seems --blockTime is our best bet
    # But even that leads to undeterministic behavior from my testing

    expected_time_of_mint = chain.time() + 2
    total_supply_cap = qd.get_total_supply_cap(expected_time_of_mint)
    total_supply = qd.totalSupply()

    # we need a qd amount such that total_supply + amount - private_minted <= total_supply_cap
    amount = random.randint(Decimal('100e24'), total_supply_cap - total_supply + qd.private_minted())
    cost = qd.qd_amt_to_usdt_amt(amount, expected_time_of_mint)
    usdt.unprotectedMint(alice, cost)
    usdt.approve(qd, cost, from_alice)

    # region mint
    qd.mint(amount, alice, from_alice)
    # endregion
    
    # smaller than 1 usdt (to account for time indeterminism)
    assert usdt.balanceOf(alice)  < Decimal('1e8')
    assert qd.balanceOf(alice)    == alice_qd_bal + amount
    assert qd.private_deposited() == private_deposited

    assert off_by_atmost_1bp(
        qd.public_deposited(),
        qd_public_deposited + cost * 78 // 100
    )
    
    assert off_by_atmost_1bp(
        usdt.balanceOf(qd),
        qd_usdt_bal + cost * 78 // 100
    )

    assert off_by_atmost_1bp(
        usdt.balanceOf(UA),
        ua_usdt_bal + cost * 22 // 100
    )