from datetime import datetime, timedelta, timezone
from decimal import Decimal

from brownie.network.account import Account

# gmt_plus_2 = timezone(timedelta(hours=2))
gmt = timezone(timedelta(hours=0))
START = int(datetime(
    year = 2022,
    month = 3,
    day = 16,
    tzinfo = gmt,
).timestamp())
LENGTH = int(timedelta(days=54).total_seconds())
END = START + LENGTH

START_PRICE = Decimal('0.22')
FINAL_PRICE = Decimal('0.96')

MINT_QD_PER_DAY_MAX = Decimal('500_000')

QD_PRECISION = Decimal('1e24')
PRICE_PRECISION = Decimal('1e18')
USDT_TO_QD_PRECISION = Decimal('1e18')

# Adjust this to try more or less possibilites
TEST_MULTIPLIER = 10

UA = Account('0x165CD37b4C644C2921454429E7F9358d18A45e14')