from brownie import *
p = project.load()
network.connect()
from_alice = {'from': accounts[0]}
test_erc20 = p.TestERC20.deploy(from_alice)
qd         = p.QD.deploy(test_erc20.address, from_alice)