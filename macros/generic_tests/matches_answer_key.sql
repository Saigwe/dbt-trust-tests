{#-
  The answer-key pattern: plant known errors in test data, list them in a seed, and require the model to find
  exactly those, no more and no fewer. A control that also flags clean rows fails, and so does one that misses a
  planted case or gets a detail wrong (an amount, a reason).

    tests:
      - trust_tests.matches_answer_key:
          arguments:
            expected: ref('planted_exceptions')     # the answer key
            key_columns: [batch_id]                 # how a finding is identified
            compare_columns: [reason, amount]       # optional: must also match
            where: "control = 'duplicate'"          # optional filter on the model

  Each failing row says whether the finding is missing, unexpected, or has different details.
-#}
{% test matches_answer_key(model, expected, key_columns, compare_columns=[], where=none) %}
{%- set cols = key_columns + compare_columns -%}
with found as (
    select distinct {{ cols | join(', ') }} from {{ model }} {% if where %}where {{ where }}{% endif %}
),

answer as (
    select distinct {{ cols | join(', ') }} from {{ expected }}
)

select
    {% for c in key_columns %}coalesce(f.{{ c }}, a.{{ c }}) as {{ c }}, {% endfor %}
    case
        when f.{{ key_columns[0] }} is null then 'missed: in the answer key, not found'
        when a.{{ key_columns[0] }} is null then 'unexpected: found, not in the answer key'
        else 'found, but details differ'
    end as problem
from found f
full outer join answer a
    on {% for c in key_columns %}f.{{ c }} = a.{{ c }}{{ " and " if not loop.last }}{% endfor %}
where f.{{ key_columns[0] }} is null
   or a.{{ key_columns[0] }} is null
   {% for c in compare_columns %}
   or not (f.{{ c }} = a.{{ c }} or (f.{{ c }} is null and a.{{ c }} is null))
   {% endfor %}
{% endtest %}
