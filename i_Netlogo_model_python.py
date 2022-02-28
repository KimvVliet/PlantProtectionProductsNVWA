import pyNetLogo
import pandas as pd
import numpy as np
import gc

def netlogo_repeat_model_2(pct_AC_end_users, pct_AC_traders, pct_Traders_EUO,
                           pct_coverage, min_prof, inspection_chance_NL_border, nr_PPPs_insp_trader,
                           insp_EUO_traders, insp_TTTO_traders, nr_of_inspectors, pct_profiling):
    netlogo = pyNetLogo.NetLogoLink(gui=False)
    netlogo.load_model('Netlogo_model/Crop_protection_products_NL_final.nlogo')

    df = pd.DataFrame(
        columns=['legal_products_end_user', 'illegal_EU_products_end_user', "NOP_products_end_user", 'pct_illegal'])
    for i in range(50):
        netlogo.command('set %_always_comply_end_users {}'.format(pct_AC_end_users))
        netlogo.command('set %_always_comply_traders {}'.format(pct_AC_traders))
        netlogo.command('set %_traders_end_user_only {}'.format(pct_Traders_EUO))
        netlogo.command('set %_coverage_of_disease_crop_combinations_legal_products {}'.format(pct_coverage))
        netlogo.command('set minimum_profit {}'.format(min_prof))
        netlogo.command('set inspection_chance_NL_border {}'.format(inspection_chance_NL_border))

        netlogo.command('set nr_of_PPPs_inspected_upon_visit_trader {}'.format(nr_PPPs_insp_trader))
        netlogo.command('set inspect_end_user_only_traders_EMA {}'.format(insp_EUO_traders))
        netlogo.command('set inspect_trader_to_trader_only_traders_EMA {}'.format(insp_TTTO_traders))
        netlogo.command('set Nr_of_inspectors {}'.format(nr_of_inspectors))
        netlogo.command('set %_profiling_used {}'.format(pct_profiling))

        netlogo.command('set progression_visualisation? False')
        netlogo.command('set fixed-seed? False')
        netlogo.command('set Nr_of_types_of_crops 5')
        netlogo.command('set Nr_of_types_of_diseases 2')
        netlogo.command('set Nr_of_end_users 300')
        netlogo.command('set Nr_of_traders 15')
        netlogo.command('set fixed_trust_period 36')
        netlogo.command('set fine-to-profit_ratio 1')
        netlogo.command('set %_avg_chance_to_get_disease 5')
        netlogo.command('set nr_of_PPPs_inspected_upon_visit_end_user 3')
        netlogo.command('set inspect_end_users_EMA 1')
        netlogo.command('setup')
        product_values = netlogo.repeat_report(
            ['legal_products_end_user', 'illegal_EU_products_end_user', "NOP_products_end_user"], 396, go='go')
        last_value_legal = np.array(product_values['legal_products_end_user'].tolist()[-1])
        last_value_illegal_EU = np.array(product_values['illegal_EU_products_end_user'].tolist()[-1])
        last_value_NOP = np.array(product_values['NOP_products_end_user'].tolist()[-1])
        pct_illegal = (last_value_illegal_EU + last_value_NOP) / (
                    last_value_illegal_EU + last_value_NOP + last_value_legal) * 100
        df2 = pd.DataFrame({'legal_products_end_user': [last_value_legal],
                            'illegal_EU_products_end_user': [last_value_illegal_EU],
                            'NOP_products_end_user': [last_value_NOP],
                            'pct_illegal': [pct_illegal]})
        df = pd.concat([df, df2], axis=0)

    mean_legal = np.mean(df['legal_products_end_user'])
    mean_illegal_EU = np.mean(df['illegal_EU_products_end_user'])
    mean_NOP = np.mean(df['NOP_products_end_user']) / (np.mean(df['NOP_products_end_user'])  + mean_legal + mean_illegal_EU) * 100
    mean_pct_illegal = np.mean(df['pct_illegal'])

    netlogo.kill_workspace()
    return (mean_NOP, mean_pct_illegal)