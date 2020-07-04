import json
import pandas as pd
import re
import csv
from datetime import datetime


def clean_html_tags(remarks):
    question_flag = "</b>" in remarks.lower() or "</strong>" in remarks.lower()
    clean = re.sub('&nbsp;', ' ', remarks)  # space
    clean = re.sub('\\xa0', ' ', clean)     # space
    clean = re.sub('\\u3000', '', clean)    # ideographic space; make empty
    clean = re.sub('(?<=<).*?(?=>)', '', clean)
    clean = re.sub('<', '', clean)
    clean = re.sub('>', '', clean)
    return(clean, question_flag)

    
def get_clean_remarks(remarks):
    question_flag = "</b>" in remarks.lower() or "</strong>" in remarks.lower()
    clean = re.sub('&nbsp;', ' ', remarks)  # space
    clean = re.sub('\\xa0', ' ', clean)     # space
    clean = re.sub('\\u3000', '', clean)    # ideographic space; make empty
    clean = re.sub('(?<=<).*?(?=>)', '', clean)
    clean = re.sub('<', '', clean)
    clean = re.sub('>', '', clean)
    return(clean, question_flag)


def get_clean_spox(titleraw, ch=True):
    if ch:
        pass
    else:
        spox = re.findall("(?<=^Foreign Ministry Spokesperson )(.+?)(?=')", titleraw)[0]
    return(spox)
