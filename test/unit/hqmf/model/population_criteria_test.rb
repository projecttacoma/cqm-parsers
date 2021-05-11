require_relative '../../../test_helper'
module HQMFModel

  class PopulationCriteriaTest  < Minitest::Test
    def setup
    end

    def test_conjunction_code

    expected={
      'IPP'=>'allTrue',
      'DENOM'=>'allTrue',
      'NUMER'=>'allTrue',
      'DENEXCEP'=>'atLeastOneTrue'
    }

    ['IPP','DENOM','NUMER','DENEXCEP'].each do |id|
      expect(HQMF::PopulationCriteria.new(id, id, id, []).conjunction_code).must_equal expected[id]
    end

    assert_raises(RuntimeError) {
      HQMF::PopulationCriteria.new("blah", 'blah', 'blah', []).conjunction_code
    }

    end
  end
end
