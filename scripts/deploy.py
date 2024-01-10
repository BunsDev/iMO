
from brownie import *

def main():
    acct = accounts.load('deploly') 

    qd = QD.deploy(
        '0xdAC17F958D2ee523a2206206994597C13D831ec7',
        {'from': acct}, publish_source = True
    )
