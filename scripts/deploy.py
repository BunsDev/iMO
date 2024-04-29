from brownie import *

def main():
    acct = accounts.load('deploy') 

    qd = MO.deploy(
        '',
        {'from': acct}, publish_source = True
    )