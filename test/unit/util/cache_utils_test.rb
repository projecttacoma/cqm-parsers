require 'test_helper'

class CacheUtilsTest < Minitest::Test

  def test_execute_caching

    CacheUtils::Cache.invalidate

    results = CacheUtils::Cache.fetch 'code_system_mappings', 1 do
      'fetch from block 1'
    end
    assert_equal results, 'fetch from block 1'

    # should not execute this block as cache not expired yet
    results = CacheUtils::Cache.fetch 'code_system_mappings', 1 do
      'fetch from different block 2'
    end
    assert_equal results, 'fetch from block 1'

    sleep 1
    # should execute this block as cache is expired
    results = CacheUtils::Cache.fetch 'code_system_mappings', 1 do
      'fetch from block 3'
    end
    assert_equal results, 'fetch from block 3'

    sleep 1
    # No block given to execute, should raise an exception
    err = assert_raises Measures::EmptyBlockException do
      CacheUtils::Cache.fetch 'code_system_mappings', 1
    end
    assert err.message.include? 'No block provided to execute'
  end
end
