import json
import pandas as pd
import re

with open('C:/Users/clara/Documents/china_fm/tutorial/mf_press.json', 'rt', encoding='utf-8') as f:
    data = json.load(f, encoding="utf-8")
