def off_by_atmost_1(x: int, y: int) -> bool:
    return abs(x - y) <= 1

def off_by_atmost_1bp(x: int, y: int) -> bool:
    return abs(x / y - 1) <= 0.01
    