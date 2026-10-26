{#-
  A masked identifier really is masked: every non-null value is a lowercase hex digest of the given length (32 for
  MD5, 64 for SHA-256), and, when `raw_values` is given, none of them equals a raw identifier.

    columns:
      - name: member_key
        tests:
          - trust_tests.hashed_identifier:
              arguments:
                length: 32
                raw_values: {relation: source('bronze', 'members'), column: member_id}   # optional leak check
-#}
{% test hashed_identifier(model, column_name, length=32, raw_values=none) %}
select {{ column_name }} as value, 'not a lowercase hex digest of length {{ length }}' as problem
from {{ model }}
where {{ column_name }} is not null
  and not {{ trust_tests.regex_matches(column_name, '[0-9a-f]{' ~ length ~ '}') }}
{% if raw_values %}
union all
select m.{{ column_name }}, 'equals a raw identifier'
from {{ model }} m
where m.{{ column_name }} in (select cast({{ raw_values.column }} as {{ dbt.type_string() }}) from {{ raw_values.relation }})
{% endif %}
{% endtest %}
