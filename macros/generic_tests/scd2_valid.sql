{#-
  A type-2 slowly changing dimension is well formed: for every entity, versions never overlap and leave no gaps, no
  version ends before it starts, and exactly one version is current.

    tests:
      - trust_tests.scd2_valid:
          arguments:
            entity_key: member_key
            valid_from: valid_from
            valid_to: valid_to            # null or a far-future date on the open version are both fine
            current_flag: is_current      # optional; when given, exactly one current version per entity
            end_convention: inclusive_day # 'exclusive' (next version starts at valid_to) or 'inclusive_day'
                                          # (next version starts the day after valid_to)

  Each failing row names the entity, the version start and the problem.
-#}
{% test scd2_valid(model, entity_key, valid_from, valid_to, current_flag=none, end_convention='exclusive') %}
{%- if end_convention not in ['exclusive', 'inclusive_day'] -%}
    {{ exceptions.raise_compiler_error("scd2_valid: end_convention must be 'exclusive' or 'inclusive_day'") }}
{%- endif -%}
{%- set expected_next = valid_to if end_convention == 'exclusive' else dbt.dateadd('day', 1, valid_to) -%}
with versions as (
    select
        {{ entity_key }} as entity_key,
        {{ valid_from }} as valid_from,
        {{ valid_to }} as valid_to,
        {{ expected_next }} as expected_next_from,
        lead({{ valid_from }}) over (partition by {{ entity_key }} order by {{ valid_from }}) as next_from
        {% if current_flag %}, {{ current_flag }} as is_current{% endif %}
    from {{ model }}
)

select entity_key, valid_from, 'overlap: next version starts before this one ends' as problem
from versions where next_from is not null and next_from < expected_next_from
union all
select entity_key, valid_from, 'gap: next version starts after this one ends'
from versions where next_from is not null and next_from > expected_next_from
union all
select entity_key, valid_from, 'ends before it starts'
from versions where valid_to is not null and valid_to < valid_from
union all
select entity_key, valid_from, 'open-ended version is not the last'
from versions where valid_to is null and next_from is not null
{% if current_flag %}
union all
select entity_key, min(valid_from), 'not exactly one current version'
from versions group by entity_key
having sum(case when is_current then 1 else 0 end) <> 1
{% endif %}
{% endtest %}
