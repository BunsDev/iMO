import pytest

from contract_types import *

@pytest.fixture(autouse=True)
def isolation(fn_isolation):
    pass

@pytest.fixture(scope='module')
def usdt(TestERC20, a) -> TestERC20Type:
    a.default = a[0]
    return TestERC20.deploy()

@pytest.fixture(scope='module')
def locker(LockerMock, a) -> LockerMockType:
    return LockerMock.deploy()

@pytest.fixture(scope='module')
def qd(QD, usdt, locker, a) -> QDType:
    qd = QD.deploy(usdt, locker)
    return qd

@pytest.fixture
def owner(a) -> Account:
    return a[0]

@pytest.fixture
def from_owner(owner) -> TxnConfig:
    return {'from': owner}

@pytest.fixture
def alice(a) -> Account:
    return a[1]

@pytest.fixture
def from_alice(alice) -> TxnConfig:
    return {'from': alice}