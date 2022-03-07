import random

from decimal import Decimal
from brownie import *

from contract_types import *
from tests.constants import *
from tests.helpers import *
from tests.fixtures import *

def test_decimals(qd: QDType):
    assert qd.decimals() == 24
    
def test_sale_start(qd: QDType):
    assert qd.SALE_START() == START

def test_mint_qd_per_day_max(qd: QDType):
    assert qd.MINT_QD_PER_DAY_MAX() == MINT_QD_PER_DAY_MAX

def test_sale_length(qd: QDType):
    assert qd.SALE_LENGTH() == LENGTH

def test_start_price(qd: QDType):
    assert qd.start_price() == int(START_PRICE * PRICE_PRECISION)

def test_final_price(qd: QDType):
    assert qd.final_price() == int(FINAL_PRICE * PRICE_PRECISION)
        
def get_expected_price(time_elapsed: int) -> Decimal:
    return (FINAL_PRICE - START_PRICE) * time_elapsed / LENGTH + START_PRICE

def test_price_formula_at_start(qd: QDType):
    for i in range(TEST_MULTIPLIER):
        price = qd.calculate_price(START)
        assert off_by_atmost_1bp(
            price,
            int(START_PRICE * PRICE_PRECISION)
        )
        
def test_price_formula_at_end(qd: QDType):
    for i in range(TEST_MULTIPLIER):
        price = qd.calculate_price(END)
        assert off_by_atmost_1bp(
            price,
            int(FINAL_PRICE * PRICE_PRECISION)
        )
        
def test_price_formula_at_random(qd: QDType):
    for i in range(TEST_MULTIPLIER * 10):
        time_elapsed = random.randint(0, LENGTH)
        expected_price = get_expected_price(time_elapsed) * PRICE_PRECISION
        price = qd.calculate_price(START + time_elapsed)
        assert off_by_atmost_1bp(
            price,
            int(expected_price)
        )
        assert price <= int(PRICE_PRECISION)
    
def test_cost_formula_at_start(qd: QDType):
    for i in range(TEST_MULTIPLIER):
        qd_amt = random.randint(0, 10 ** 34)
        usdt_amt = qd.qd_amt_to_usdt_amt(qd_amt, START)
        expected_qd_amt = int(qd_amt * get_expected_price(0) /  USDT_TO_QD_PRECISION)
        assert off_by_atmost_1bp(
            usdt_amt,
            expected_qd_amt
        )

def test_cost_formula_at_end(qd: QDType):
    for i in range(TEST_MULTIPLIER):
        qd_amt = random.randint(0, 10 ** 34)
        usdt_amt = qd.qd_amt_to_usdt_amt(qd_amt, END)
        expected_qd_amt = int(qd_amt * get_expected_price(LENGTH) / USDT_TO_QD_PRECISION)
        assert off_by_atmost_1bp(
            usdt_amt,
            expected_qd_amt
        )

def test_cost_formula_at_random(qd: QDType):
    for i in range(TEST_MULTIPLIER * 10):
        qd_amt = random.randint(0, 10 ** 34)
        time_elapsed = random.randint(0, LENGTH)
        usdt_amt = qd.qd_amt_to_usdt_amt(qd_amt, START + time_elapsed)
        expected_price = get_expected_price(time_elapsed)
        expected_qd_amt = int(qd_amt * expected_price / USDT_TO_QD_PRECISION)
        assert off_by_atmost_1bp(
            usdt_amt,
            expected_qd_amt
        )
        assert usdt_amt * USDT_TO_QD_PRECISION <= qd_amt

def test_total_supply_cap_at_start(qd: QDType):
    total_supply_cap = qd.get_total_supply_cap(START)
    assert total_supply_cap == 0

def test_total_supply_cap_at_end(qd: QDType):
    total_supply_cap = qd.get_total_supply_cap(END)
    # here we want a step function on purpose
    assert total_supply_cap == LENGTH * int(QD_PRECISION) * MINT_QD_PER_DAY_MAX // (24 * 60 * 60)

def test_total_supply_cap_at_random(qd: QDType):
    time_elapsed = random.randint(0, LENGTH)
    total_supply_cap = qd.get_total_supply_cap(time_elapsed + START)
    assert total_supply_cap == int(QD_PRECISION) * MINT_QD_PER_DAY_MAX * time_elapsed // (24 * 60 * 60)
    
    