class_name PetIcons
## Pictures of the pets for the pet slots (the action bar, inventory, stable
## and breeder): each species rendered from its own model, as it looks in the
## game (textures/icons/pets/<species>.png, made by tools/pet_icons.gd),
## shrunk to the size asked for and cached.

const DIR := "res://textures/icons/pets/"

static var _cache := {}


## The species' picture, `size` pixels square, or null if it has none (then
## the slot draws its own).
static func texture(species: CreatureSpecies, size: int) -> Texture2D:
	size = maxi(size, 8)
	var key := "%s|%d" % [species.display_name, size]
	if not _cache.has(key):
		var path := DIR + species.display_name.to_lower().replace(" ", "_") + ".png"
		var picture: Texture2D = null
		if ResourceLoader.exists(path):
			var image := (load(path) as Texture2D).get_image()
			if image.is_compressed():
				image.decompress()
			image.convert(Image.FORMAT_RGBA8)
			image.resize(size, size, Image.INTERPOLATE_LANCZOS)
			picture = ImageTexture.create_from_image(image)
		_cache[key] = picture
	return _cache[key]
