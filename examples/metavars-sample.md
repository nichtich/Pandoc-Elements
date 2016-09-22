---
title: Metavars *example*
tested: true
list:
 - 1
 - 2
blocks: |
  This is a paragraph.

  An another paragraph.
fooReference: '{{foo}}'
...

# {{title}}

Non-existing fields {{foo}} or fields of wrong type ({{list}}, {{tested}},
{{blocks}}...) are replaced by the empty string.

* {{blocks}}

* {{title}}

* {{foo}}

* {{tested}}

* not {{blocks}} 

{{fooReference}}

