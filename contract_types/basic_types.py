from typing import Union, TypedDict

from brownie.network.contract import ProjectContract
from brownie.network.account import Account

EvmAccount = Union[Account, ProjectContract]

TxnConfig = TypedDict('TxnConfig', {'from': EvmAccount})