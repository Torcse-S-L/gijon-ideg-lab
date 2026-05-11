import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))
exec(open(os.path.join(os.path.dirname(__file__), 'run_static_tests.py')).read().split('if __name__')[0])
suite_structure(); suite_yaml(); suite_sql(); suite_env()
suite_readme(); suite_git(); suite_compose(); suite_scripts()
suite_docs(); suite_prometheus()
for r in results:
    if r['status'] != 'PASS':
        print(r['status'], '|', r['suite'], '|', r['name'], '|', r['detail'][:100])
