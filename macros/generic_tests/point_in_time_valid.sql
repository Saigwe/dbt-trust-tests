{#-
  A point-in-time join is right: each fact row points at the dimension version that was valid when the event
  happened, not just any version of the entity. Put it on the fact's foreign-key column.

    columns:
      - name: member_sk
        tests:
          - trust_tests.point_in_time_valid:
              arguments:
                to: ref('dim_member')
                field: member_sk               # the dimension's surrogate key
                event_at: service_from_date    # the fact's event date or timestamp
                valid_from: valid_from
                valid_to: valid_to             # null means open-ended
                end_convention: inclusive_day  # 'exclusive' or 'inclusive_day', as in scd2_valid

  Rows whose key has no dimension row at all fail too (that is a relationships failure as well, but a PIT join
  that finds nothing is never right).
-#}
{% test point_in_time_valid(model, column_name, to, field, event_at, valid_from, valid_to, end_convention='exclusive') %}
select f.{{ column_name }} as fact_key, f.{{ event_at }} as event_at, d.{{ valid_from }} as valid_from, d.{{ valid_to }} as valid_to,
       case when d.{{ field }} is null then 'no dimension row' else 'event outside the version window' end as problem
from {{ model }} f
left join {{ to }} d on d.{{ field }} = f.{{ column_name }}
where f.{{ column_name }} is not null
  and (d.{{ field }} is null
       or f.{{ event_at }} < d.{{ valid_from }}
       or (d.{{ valid_to }} is not null and
           f.{{ event_at }} {{ '>=' if end_convention == 'exclusive' else '>' }} d.{{ valid_to }}))
{% endtest %}
