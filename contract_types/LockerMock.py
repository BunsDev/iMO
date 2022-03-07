from typing import Tuple, Union
    
from brownie.network.contract import ProjectContract
from brownie.network.transaction import TransactionReceipt

from contract_types.basic_types import *

from decimal import Decimal

class LockerMockType(ProjectContract):
    def lockToken(self, ethToken: EvmAccount, amount: Union[int, Decimal], accountId: str, d: Union[TxnConfig, None] = None) -> TransactionReceipt:
        ...

