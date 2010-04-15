_.mixin {
  group: (list, byFn, agFn) ->
    lastGroup: null
    agFn ?= (i) -> i
    _(list).chain().sortBy(byFn).reduce([], (groups, item) ->
      group: byFn item
      if _(groups).isEmpty() or not _(group).isEqual(lastGroup)
        lastGroup: group
        groups.push []
      _(groups).last().push item
      groups
    ).map(agFn).value()
}