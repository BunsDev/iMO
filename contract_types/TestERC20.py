from typing import Tuple, Union
    
from brownie.network.contract import ProjectContract
from brownie.network.transaction import TransactionReceipt

from contract_types.basic_types import *

from decimal import Decimal

class TestERC20Type(ProjectContract):
    def allowance(self, owner: EvmAccount, spender: EvmAccount, d: Union[TxnConfig, None] = None) -> int:
        ...

    def approve(self, spender: EvmAccount, amount: Union[int, Decimal], d: Union[TxnConfig, None] = None) -> TransactionReceipt:
        ...

    def balanceOf(self, account: EvmAccount, d: Union[TxnConfig, None] = None) -> int:
        ...

    def decimals(self, d: Union[TxnConfig, None] = None) -> int:
        ...

    def decreaseAllowance(self, spender: EvmAccount, subtractedValue: Union[int, Decimal], d: Union[TxnConfig, None] = None) -> TransactionReceipt:
        ...

    def increaseAllowance(self, spender: EvmAccount, addedValue: Union[int, Decimal], d: Union[TxnConfig, None] = None) -> TransactionReceipt:
        ...

    def name(self, d: Union[TxnConfig, None] = None) -> str:
        ...

    def symbol(self, d: Union[TxnConfig, None] = None) -> str:
        ...

    def totalSupply(self, d: Union[TxnConfig, None] = None) -> int:
        ...

    def transfer(self, to: EvmAccount, amount: Union[int, Decimal], d: Union[TxnConfig, None] = None) -> TransactionReceipt:
        ...

    def transferFrom(self, from_: EvmAccount, to: EvmAccount, amount: Union[int, Decimal], d: Union[TxnConfig, None] = None) -> TransactionReceipt:
        ...

    def unprotectedMint(self, _account: EvmAccount, _amount: Union[int, Decimal], d: Union[TxnConfig, None] = None) -> TransactionReceipt:
        ...

