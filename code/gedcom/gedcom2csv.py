#!/usr/bin/python3
# usage: ./gedcom2csv.py file.ged > file.csv
# https://pypi.org/project/python-gedcom/
import sys
from gedcom.element.individual import IndividualElement
from gedcom.parser import Parser

file_path = sys.argv[1]
gedcom_parser = Parser()
gedcom_parser.parse_file(file_path)

root_child_elements = gedcom_parser.get_root_child_elements()

print("first,last,birth,death,gender,id,mother,father")
root_child_elements = gedcom_parser.get_root_child_elements()
for e in root_child_elements:
    if isinstance(e, IndividualElement):
        (first,last) = e.get_name()
        data = [first, last, str(e.get_birth_year()),str(e.get_death_year()),e.get_gender(),e.get_pointer()]
        parents = gedcom_parser.get_parents(e)
        data = data + ([p.get_pointer() for p in parents if p.get_gender() == 'F'] or [''])
        data = data + ([p.get_pointer() for p in parents if p.get_gender() == 'M'] or [''])
        print(",".join(data))

