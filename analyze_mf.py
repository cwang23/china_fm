import json
import pandas as pd
import re

with open('C:/Users/clara/Documents/china_fm/tutorial/mf_press.json', 'rt', encoding='utf-8') as f:
    data = json.load(f, encoding="utf-8")

def clean_html_tags(remarks):
    clean = re.sub('(?<=<).*?(?=>)', '', remarks)
    clean = re.sub('<', '', clean)
    clean = re.sub('>', '', clean)
    return(clean)

for i in range(0, len(data)):
    print(i)
    entry = data[i]
    title = entry['title']
    line = entry['text']
    cleanstring = ''
    for x in line:
        clean = clean_html_tags(x)
        cleanstring = cleanstring + clean

    print(title)
    if 'Q:' not in cleanstring or 'A:' not in cleanstring:
        print(cleanstring)
