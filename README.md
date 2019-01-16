[![codecov](https://codecov.io/gh/projecttacoma/cqm-parsers/branch/master/graph/badge.svg)](https://codecov.io/gh/projecttacoma/cqm-parsers)


cqm-parsers
===========

This project contains libraries for parsing HQMF documents.




####MAT Package Loading
To load measures from a MAT package file into the measure model, use the `Measures::CqlLoader` class. It can be used to create an array of measure models. For a composite measure, the array will contain the component measures and the last element will be the composite measure. For a non-composite measure (most measures), the array will contain one item.
Example measure loading:

```ruby
vsac_options = { profile: APP_CONFIG['vsac']['default_profile'] }
measure_details = { 'episode_of_care'=> false }
measure_file = File.new File.join('some/path/CMS158_v5_4_Artifacts.zip')

value_set_loader = Measures::VSACValueSetLoader.new(vsac_options, get_ticket_granting_ticket)
loader = Measures::CqlLoader.new(measure_file, measure_details, value_set_loader)
measures = loader.extract_measures    #this is now an array of the measures
```
Note that a different value set loader could be passed in; for example if you had a file containing value sets you could create a loader that read the value sets from file instead of fetching them from VSAC.



License
=======

Copyright 2018 The MITRE Corporation

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
