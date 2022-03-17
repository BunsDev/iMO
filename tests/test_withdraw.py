import random

from brownie import *
import brownie

from contract_types import *
from tests.constants import *
from tests.fixtures import *
from tests.test_mint import *

def test_withdraw(
    qd: QDType,
    usdt: TestERC20Type,
    locker: LockerMockType,
    alice: Account,
    owner: Account,
    from_alice: TxnConfig,
    from_owner: TxnConfig
):
    test_mint_from_owner(qd, usdt, owner, from_owner)
    # Need to sleep so Alice can mint some tokens
    chain.sleep(60 * 60)
    test_mint_from_alice(qd, usdt, alice, from_alice)
    # Need to sleep so Alice can mint some tokens
    chain.sleep(60 * 60)
    test_mint_from_alice(qd, usdt, alice, from_alice)
    # Need to sleep so Alice can mint some tokens
    chain.sleep(60 * 60)
    test_mint_from_alice(qd, usdt, alice, from_alice)
    # Owner can mint without cap
    test_mint_from_owner(qd, usdt, owner, from_owner, count = 2)
    
    time_elapsed = END - chain.time()
    chain.sleep(time_elapsed)
    
    public_deposited = qd.public_deposited()
    private_deposited = qd.private_deposited()
    # region withdraw
    qd.withdraw()
    # endregion
    
    assert usdt.balanceOf(qd)     == 0
    assert usdt.balanceOf(locker) == public_deposited
    assert usdt.balanceOf(owner)  == private_deposited
    # owner minted four times
    assert qd.balanceOf(owner)    == Decimal('2.7e30') * 6
    assert qd.public_deposited()  == 0
    
    
    