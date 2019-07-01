[![Build Status](https://travis-ci.com/projecttacoma/cqm-parsers.svg?branch=master)](https://travis-ci.com/projecttacoma/cqm-parsers)
[![codecov](https://codecov.io/gh/projecttacoma/cqm-parsers/branch/master/graph/badge.svg)](https://codecov.io/gh/projecttacoma/cqm-parsers)
[![Gem Version](https://badge.fury.io/rb/cqm-parsers.svg)](https://badge.fury.io/rb/cqm-parsers)

# cqm-parsers

This project contains libraries for parsing HQMF documents and parsing MAT packages.

## Usage (MAT Package Loading)

To load measures from a MAT package file into the measure model, use the `Measures::CqlLoader` class. It can be used to create an array of measure models. For a composite measure, the array will contain the component measures and the last element will be the composite measure. For a non-composite measure (most measures), the array will contain one item.
Example measure loading:

```ruby

# Set the VSACValueSetLoader options; in this example we are fetching a specific profile.
vsac_options = { profile: 'MU2 Update 2016-04-01' }

# Set the measure details. For defaults, you can just pass in {}.
measure_details = { 'episode_of_care'=> false }

# Load a MAT package from test fixtures.
measure_file = File.new File.join('some/path/CMS158_v5_4_Artifacts.zip')

# Initialize a value set loader, in this case we are using the VSACValueSetLoader.
value_set_loader = Measures::VSACValueSetLoader.new(vsac_options, get_ticket_granting_ticket)

# Initialize the CqlLoader with the needed parameters.
loader = Measures::CqlLoader.new(measure_file, measure_details, value_set_loader)
# Build an array of measure models.
measures = loader.extract_measures

```

Note that a different value set loader could be passed in; for example if you had a file containing value sets you could create a loader that read the value sets from file instead of fetching them from VSAC.

## Running the tests

```bash

bundle exec rake test

```


## Versioning

Starting with version **2.0.0** released on !!date!!, cqm-parsers versioning has the format **X.Y.Z**, where:

* **X** maps to a version of the CQL-based HQMF IG. See the table below to see the existing mapping to CQL-based HQMF IG versions.

  | X | CQL-based HQMF IG|
  | --- | --- |
  | 2 | R1 STU3 |

* **Y** indicates major changes (incompatible API changes)

* **Z** indicates minor changes (added functionality in a backwards-compatible manner) and patch changes (backwards-compatible bug fixes)

For the versions available, see [tags on this repository](https://github.com/projecttacoma/cqm-parsers/tags).

## License

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
