from copy import copy
import json
from keyword import iskeyword
import os
import sys

def sol_to_py(sol: str, input: bool) -> str:
    if sol.startswith('int') or sol.startswith('uint'):
        if input:
            return 'Union[int, Decimal]'
        else:
            return 'int'
    
    if sol.startswith('contract') or sol.startswith('address'): return 'EvmAccount'
    
    if sol.startswith('bool'): return 'bool'

    if sol.startswith('string'): return 'str'
    
    if sol.startswith('bytes'): return 'bytes'

    raise Exception()

template = """from typing import Tuple, Union
    
from brownie.network.contract import ProjectContract
from brownie.network.transaction import TransactionReceipt

from tests.types.basic_types import *

from decimal import Decimal

"""

def main():
    fns = os.listdir('./tests/types/abis/')
    paths = [f'./tests/types/abis/{fn}' for fn in fns]
    for fn, path in zip(fns, paths):
        fn_base = fn.split('.json')[0]
        class_name = f'{fn_base}Type'
        res = copy(template)
        res += f'class {class_name}(ProjectContract):\n'
        abi = json.load(open(path))
        for el in abi:
            try:
                if el['type'] == 'function':
                    # region function_name
                    function_name = el['name']
                    # endregion function_name

                    # region params
                    inputs = el['inputs']
                    params = []
                    # We need to keep track of unknown parameters, so we don't name them equally
                    no_of_unknowns = 0
                    for input in inputs:
                        if not (param_name := input['name']):
                            param_name = f'_unkown_{no_of_unknowns}'
                            no_of_unknowns += 1
                        if iskeyword(param_name):
                            param_name += '_'
                        params.append((param_name, sol_to_py(input['type'], input=True)))
                        del param_name
                    
                    del inputs

                    params_strs = ['self'] + [f'{p[0]}: {p[1]}' for p in params] + ['d: Union[TxnConfig, None] = None']

                    del params

                    params_str = ', '.join(params_strs)
                    
                    del params_strs
                    
                    # endregion params
                    
                    # region return_values
                    
                    if el['stateMutability'] in ['pure', 'view']:
                        return_values = [sol_to_py(output['type'], input=False) for output in el['outputs']]
                        
                        if len(return_values) == 0:
                            return_values_str = 'None'
                        elif len(return_values) == 1:
                            return_values_str = return_values[0]
                        else:
                            return_values_str = 'Tuple[' + ', '.join(return_values) + ']'
                        del return_values
                    else:
                        return_values_str = 'TransactionReceipt'
                        
                    # endregion return_values

                    # region create method
                    sub = f'    def {function_name}({params_str}) -> {return_values_str}:\n'
                    res += sub + ' ' * 8 + '...' + '\n' * 2
                    # endregion create method

            except:
                print(f'el failed: {el}')
                raise Exception()
        with open(f'./tests/types/{fn_base}.py', 'w') as f:
            f.write(res)
    
if __name__ == '__main__':
    main()