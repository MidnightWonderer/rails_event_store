## Adding matchers to the project

Add this line to your application's Gemfile:

```ruby
group :test do
  gem 'rails_event_store-rspec'
end
```

## Matchers usage

### be_event

The `be_event` matcher enables you to make expectations on a domain event. It exposes fluent interface.

```ruby
OrderPlaced  = Class.new(RailsEventStore::Event)
domain_event = OrderPlaced.new(
  data: {
    order_id: 42,
    net_value: BigDecimal.new("1999.0")
  },
  metadata: {
    remote_ip: '1.2.3.4'
  }
)

expect(domain_event)
  .to(be_an_event(OrderPlaced)
    .with_data(order_id: 42, net_value: BigDecimal.new("1999.0"))
    .with_metadata(remote_ip: '1.2.3.4'))
```

By default the behaviour of `with_data` and `with_metadata` is not strict, that is the expectation is met when all specified values for keys match. Additional data or metadata that is not specified to be expected does not change the outcome.

```ruby
domain_event = OrderPlaced.new(
  data: {
    order_id: 42,
    net_value: BigDecimal.new("1999.0")
  }
)

# this would pass even though data contains also net_value
expect(domain_event).to be_an_event(OrderPlaced).with_data(order_id: 42)
```

This matcher is both [composable](http://rspec.info/blog/2014/01/new-in-rspec-3-composable-matchers/) and accepting [built-in matchers](https://relishapp.com/rspec/rspec-expectations/v/3-6/docs/built-in-matchers) as a part of an expectation.

```ruby
expect(domain_event).to be_an_event(OrderPlaced).with_data(order_id: kind_of(Integer))
expect([domain_event]).to include(an_event(OrderPlaced))
```

If you depend on matching the exact data or metadata, there's a `strict` modifier.

```ruby
domain_event = OrderPlaced.new(
  data: {
    order_id: 42,
    net_value: BigDecimal.new("1999.0")
  }
)

# this would fail as data contains unexpected net_value
expect(domain_event).to be_an_event(OrderPlaced).with_data(order_id: 42).strict
```

Mind that `strict` makes both `with_data` and `with_metadata` behave in a stricter way. If you need to mix both, i.e. strict data but non-strict metadata then consider composing matchers.

```ruby
expect(domain_event)
  .to(be_event(OrderPlaced).with_data(order_id: 42, net_value: BigDecimal.new("1999.0")).strict
    .and(an_event(OrderPlaced).with_metadata(timestamp: kind_of(Time)))
```

You may have noticed the same matcher being referenced as `be_event`, `be_an_event` and `an_event`. There's also just `event`. Use whichever reads better grammatically.

### have_published

Use this matcher to target `event_store` and reading from streams specifically.
In a simplest form it would read all streams backward up to a page limit (100 events) and check whether the expectation holds true. Its behaviour can be best compared to the `include` matcher — it is satisfied by at least one element present in the collection. You're encouraged to compose it with `be_event`.

```ruby
event_store = RailsEventStore::Client.new
event_store.publish_event(OrderPlaced.new(data: { order_id: 42 }))

expect(event_store).to have_published(an_event(OrderPlaced))
```

Expectation can be narrowed to the specific stream.

```ruby
event_store = RailsEventStore::Client.new
event_store.publish_event(OrderPlaced.new(data: { order_id: 42 }), stream_name: "Order$42")

expect(event_store).to have_published(an_event(OrderPlaced)).in_stream("Order$42")
```

It is sometimes important to ensure no additional events have been published. Luckliy there's a modifier to cover that usecase.

```ruby
expect(event_store).not_to have_published(an_event(OrderPlaced)).once
expect(event_store).to have_published(an_event(OrderPlaced)).exactly(2).times
```

Finally you can make expectation on several events at once.

```ruby
expect(event_store).to have_published(
  an_event(OrderPlaced),
  an_event(OrderExpired).with_data(expired_at: be_between(Date.yesterday, Date.tomorrow))
)
```

If there's a usecase not covered by examples above or you need a different set of events to make expectations on you can always resort to a more verbose approach and skip `have_published`.

```ruby
expect(event_store.read_events_forward("OrderAuditLog$42", count: 2)).to eq([
  an_event(OrderPlaced),
  an_event(OrderExpired)
])
```

### have_applied

This matcher is intended to be used on [aggregate root](https://github.com/RailsEventStore/rails_event_store/tree/master/aggregate_root#usage). Behaviour is almost identical to `have_published` counterpart, except the concept of stream. Expecations are made against internal unpublished events collection.

```ruby
class Order
  include AggregateRoot
  HasBeenAlreadySubmitted = Class.new(StandardError)
  HasExpired              = Class.new(StandardError)

  def initialize
    self.state = :new
    # any other code here
  end

  def submit
    raise HasBeenAlreadySubmitted if state == :submitted
    raise HasExpired if state == :expired
    apply OrderSubmitted.new(data: {delivery_date: Time.now + 24.hours})
  end

  def expire
    apply OrderExpired.new
  end

  private
  attr_accessor :state

  def apply_order_submitted(event)
    self.state = :submitted
  end

  def apply_order_expired(event)
    self.state = :expired
  end
end
```

```ruby
aggregate_root = Order.new
aggregate_root.submit

expect(aggregate_root).to have_applied(event(OrderSubmitted)).once
```
