class_name KingdomInventory
extends Object

enum KingdomResource {
	GOLD,
	WOOD,
	MEAT
}

# The amounts of resources that are currently owned.
var resources_owned : Dictionary[KingdomResource, float] = {}

# The upper limits on the amounts of resources that can be held.
var resource_maximums : Dictionary[KingdomResource, float] = {}

func _init() -> void:
	for key : KingdomResource in KingdomResource.keys():
		resources_owned[key] = 0
		resource_maximums[key] = INF

func set_resource_maximums(new_maximums : Dictionary[KingdomResource, float]) -> void:
	for key in KingdomResource:
		assert(
			new_maximums.has(key),
			"new_maximums must contain keys for all resources, but is missing '" + KingdomResource.values()[key] + "'"
		)
	
	resource_maximums = new_maximums

## Returns the maximum quantity that can be held of this resource.
func get_amount_owned(resource : KingdomResource) -> float:
	return resources_owned[resource]

func get_resource_maximum(resource : KingdomResource) -> float:
	return resource_maximums[resource]

## Returns true if sufficient resources are owned to spend the provided amount of the given resource.
## amount should be positive.
func can_spend(resource : KingdomResource, amount : float) -> bool:
	assert(amount >= 0)
	return get_amount_owned(resource) - amount >= 0

## Returns true if sufficient space exists to gain the provided amount of the given resource.
func can_gain(resource : KingdomResource, amount : float) -> bool:
	assert(amount >= 0)
	return get_amount_owned(resource) + amount <= get_resource_maximum(resource)

## Deducts the provided amount from the owned quantity of the given resource.
## amount should be positive.
## If force is false (the default) then attempting to spend unavailable resources will crash the game IN THE EDITOR ONLY.
func spend(resource : KingdomResource, amount : float, force : bool = false) -> void:
	assert(force or can_spend(resource, amount))
	assert(amount >= 0)
	resources_owned[resource] -= amount

## Adds the provided amount to the owned quantity of the given resource.
## If force is false (the default) then attempting to gain resources without space will crash the game IN THE EDITOR ONLY.
func gain(resource : KingdomResource, amount : float, force : bool = false) -> void:
	assert(force or can_gain(resource, amount))
	assert(amount >= 0)
	resources_owned[resource] += amount

## Accepts a dictionary mapping resources onto the quantities to spend.
## Returns true if the necessary resources are all owned, false otherwise.
func can_spend_all(resources_to_spend : Dictionary[KingdomResource, float]) -> bool:
	for key : KingdomResource in resources_to_spend.keys():
		if not can_spend(key, resources_to_spend[key]):
			return false
	
	return true

## Accepts a dictionary mapping resources onto the quantities to gain.
## Returns true if the necessary space exists for all the resources to gain, false otherwise.
func can_gain_all(resources_to_gain : Dictionary[KingdomResource, float]) -> bool:
	for key : KingdomResource in resources_to_gain.keys():
		if not can_gain(key, resources_to_gain[key]):
			return false
	
	return true

## Accepts a dictionary mapping resources onto the quantities to spend.
## Reduces all resources by the associatewd amounts.
## If force is false (the default) then attempting to spend unavailable resources will crash the game IN THE EDITOR ONLY.
func spend_all(resources_to_spend : Dictionary[KingdomResource, float], force : bool = false) -> void:
	for key in resources_to_spend.keys():
		spend(key, resources_to_spend[key], force)

## Accepts a dictionary mapping resources onto the quantities to gain.
## Increases all resources by the associatewd amounts.
## If force is false (the default) then attempting to gain resources without space will crash the game IN THE EDITOR ONLY.
func gain_all(resources_to_gain : Dictionary[KingdomResource, float], force : bool = false) -> void:
	for key in resources_to_gain.keys():
		gain(key, resources_to_gain[key], force)
