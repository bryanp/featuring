**Feature flags for Ruby objects.**

### Declaring Feature Flags

Feature flags can be declared on modules or classes:

```ruby
module Features
  extend Featuring::Declarable

  feature :some_feature
end

class ObjectWithFeatures
  extend Featuring::Declarable

  feature :some_feature
end
```

By default, a feature flag is disabled. It can be enabled by specifying a value:

```ruby
module Features
  extend Featuring::Declarable

  feature :some_feature, true
end
```

Feature flags can also compute a value using a block:

```ruby
module Features
  extend Featuring::Declarable

  feature :some_feature do
    # perform some complex logic
  end
end
```

The truthiness of the block's return value determines if the feature is enabled or disabled.

### Checking Feature Flags

Each feature flag has a corresponding method to check its value:

```ruby
module Features
  extend Featuring::Declarable

  feature :some_feature
end

Features.some_feature?
=> false
```

When using feature flags on an object, checks are available through the `features` instance method:

```ruby
class ObjectWithFeatures
  extend Featuring::Declarable

  feature :some_feature
end

instance = ObjectWithFeatures.new
instance.features.some_feature?
=> false
```

#### Passing values to feature flag blocks

When using feature flag blocks, values can be passed through the check method:

```ruby
module Features
  extend Featuring::Declarable

  feature :some_feature do |value|
    value == :some_value
  end
end

Features.some_feature?(:some_value)
=> true

Features.some_feature?(:some_other_value)
=> false
```

#### Truthiness 100% guaranteed

Check methods are guaranteed to only return `true` or `false`:

```ruby
module Features
  extend Featuring::Declarable

  feature :some_feature do
    :foo
  end
end

Features.some_feature?
=> true
```

#### Check method context

Check methods have access to their context:

```ruby
class ObjectWithFeatures
  extend Featuring::Declarable

  feature :some_feature do
    enabled?
  end

  def enabled?
    true
  end
end

instance = ObjectWithFeatures.new
instance.features.some_feature?
=> true
```

Note that this happens through delegators, which means that instance variables are not accessible to the feature flag. For cases like this, define an `attr_accessor`.

### Persisting Feature Flags

Feature flag persistence can be added to any object with feature flags. Right now, persistence to an ActiveRecord model is supported. Postgres is currently the only supported database.

Enable persistence on an object by including the adapter:

```ruby
class ObjectWithFeatures
  include Featuring::Persistence::ActiveRecord
  extend Featuring::Declarable

  feature :some_feature
end
```

While persistence is anticipated to be used mostly for other ActiveRecord models, feature flags can be persisted for any object that exposes a deterministic value for `id`.

Here's the example we'll use for the next few sections:

```ruby
class User < ActiveRecord::Base
  include Featuring::Persistence::ActiveRecord
  extend Featuring::Declarable

  feature :some_feature
end
```

Nothing is persisted by default. Instead, each feature flag must be persisted explicitly. This means that by default, checks fall back to the default value of a feature flag:

```ruby
User.find(1).features.some_feature?
=> false
```

#### Persisting a default value

Use the `persist` method to persist a feature flag with its default value:

```ruby
User.find(1).features.persist :some_feature
User.find(1).features.some_feature?
=> false
```

This can be used to isolate objects from future changes to default values.

#### Persisting a specific value

Use the `set` method to persist a feature flag with a specific value:

```ruby
User.find(1).features.set :some_feature, true
User.find(1).features.some_feature?
=> true
```

#### Enabling a feature flag

Enable a flag using the `enable` method:

```ruby
User.find(1).features.enable :some_feature
User.find(1).features.some_feature?
=> true
```

#### Disabling a feature flag

Disable a flag using the `disable` method:

```ruby
User.find(1).features.disable :some_feature
User.find(1).features.some_feature?
=> false
```

#### Resetting a feature flag

Reset a flag using the `reset` method:

```ruby
User.find(1).features.enable :some_feature
User.find(1).features.reset :some_feature
User.find(1).features.some_feature?
=> false
```

#### Persisting many feature flags at once

Multiple feature flags can be persisted using the `transaction` method:

```ruby
User.find(1).features.transaction |features|
  features.enable :some_feature
  features.disable :some_other_feature
end

User.find(1).features.some_feature?
=> true

User.find(1).features.some_other_feature?
=> false
```

Persistence happens in one step. Using the ActiveRecord adapter, all feature flag changes within the transaction block will be committed in a single `INSERT` or `UPDATE` query.

#### Reloading the cache

For performance, persisted feature flags are loaded only once for an instance. This means if a different value is persisted for a feature flag in another part of the system, the change won't be immediately available to other instances until they are reloaded:

```ruby
user = User.find(1)

# enable somewhere else
User.find(1).features.enable :some_feature

# feature still appears disabled for existing instances
user.features.some_feature?
=> false

# reloading the features invalidates the cache:
user.features.reload
user.features.some_feature?
=> true
```

When used in an ActiveRecord model, feature flags are automatically reloaded with the object:

```ruby
user = User.find(1)

# enable somewhere else
User.find(1).features.enable :some_feature

# feature still appears disabled for existing instances
user.features.some_feature?
=> false

# reloading the model invalidates the cache:
user.reload
user.features.some_feature?
=> true
```

#### Checking the persisted status

The persisted status of a flag can be checked with the `persisted?` method:

```ruby
User.find(1).features.persisted?(:some_feature)
=> false

User.find(1).features.persist :some_feature

User.find(1).features.persisted?(:some_feature)
=> true
```

Checking if a specific value is persisted for a flag is also possible:

```ruby
User.find(1).features.enable :some_feature

User.find(1).features.persisted?(:some_feature, true)
=> true

User.find(1).features.persisted?(:some_feature, false)
=> false
```

An example of where this is useful can be found in the next section.

#### A note about precedence

In most cases, a feature flag's persisted value takes precedence over its default value. The single exception to this rule is when using feature flags defined with blocks. If the persisted value is `false`, the persisted value is always given precedence. But if the persisted value is `true`, the value returned from the block must also be truthy. This lets us do complex things like enable a feature 50% of the time for users that are given explicit access to a feature:

```ruby
class User < ActiveRecord::Base
  include Featuring::Persistence::ActiveRecord
  extend Featuring::Declarable

  feature :some_feature do
    [true, false].sample && features.persisted?(:some_feature)
  end
end
```

#### How ActiveRecord persistence works

Feature flags are persisted to a database table with a polymorphic association to flaggable objects. By default, the ActiveRecord adapter expects a top-level `FeatureFlag` model to be available, along with a `feature_flags` database table. The table is expected to contain the following fields:

* `flaggable_id`: `integer` column containing the flaggable object id
* `flaggable_type`: `string` column containing the flaggable object type
* `metadata`: `jsonb` column containing the feature flag values

### Composing Feature Flags

Feature flags can be defined in various modules and composed together:

```ruby
module Features
  extend Featuring::Declarable
  feature :some_feature, true
end

module AllTheFeatures
  extend Features

  extend Featuring::Declarable
  feature :another_feature, true
end

class ObjectWithFeatures
  include AllTheFeatures
end

instance = ObjectWithFeatures.new

instance.some_feature?
=> true

instance.another_feature?
=> true
```

#### Calling `super` for overloaded feature flags

Super is fully supported! Here's an example of how it can be useful:

```ruby
module Features
  extend Featuring::Declarable

  feature :some_feature do
    [true, false].sample
  end
end

class ObjectWithFeatures
  include Features

  extend Featuring::Declarable
  feature :some_feature do
    persisted?(:some_feature) || super()
  end
end

User.find(1).features.some_feature?
=> true/false at random

User.find(1).features.enable :some_feature

User.find(1).features.some_feature?
=> true (always)
```

### Serializing Feature Flags

Feature flag values can be serialized using `serialize`:

```ruby
module Features
  extend Featuring::Declarable

  feature :some_enabled_feature, true
  feature :some_disable_feature, false
end

Features.serialize
=> {
  some_enabled_feature: true,
  some_disabled_feature: false
}
```

All flags, persisted or not, will be included in the result.

#### Including specific feature flags

Include only specific feature flags in the serialized result using `include`:

```ruby
module Features
  extend Featuring::Declarable

  feature :some_enabled_feature, true
  feature :some_disable_feature, false
end

Features.serialize do |serializer|
  serializer.include :some_enabled_feature
end
=> {
  some_enabled_feature: true
}
```

#### Excluding specific feature flags

Exclude specific feature flags in the serialized result using `exclude`:

```ruby
module Features
  extend Featuring::Declarable

  feature :some_enabled_feature, true
  feature :some_disable_feature, false
end

Features.serialize do |serializer|
  serializer.exclude :some_enabled_feature
end
=> {
  some_disabled_feature: false
}
```

#### Providing context for complex feature flags

Serializing complex feature flags will fail if they require an argument:

```ruby
module Features
  extend Featuring::Declarable

  feature :some_complex_feature do |value|
    value == :some_value
  end
end

Features.serialize
=> ArgumentError
```

Context can be provided for these feature flag using `context`:

```ruby
Features.serialize do |serializer|
  serializer.context :some_complex_feature, :some_value
end
=> {
  some_complex_feature: true
}
```
