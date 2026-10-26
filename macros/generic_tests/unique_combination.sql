{#-
  The model's grain: the given columns form a unique key. Each failing row is one duplicated key and how often it
  occurs.

    tests:
      - trust_tests.unique_combination:
          arguments: {columns: [account_id, month]}
-#}
{% test unique_combination(model, columns) %}
select {{ columns | join(', ') }}, count(*) as n_rows
from {{ model }}
group by {{ columns | join(', ') }}
having count(*) > 1
{% endtest %}
