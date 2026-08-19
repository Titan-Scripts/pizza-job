--[[
    ox_inventory does not read item definitions from other resources -
    copy this entry into your ox_inventory/data/items.lua (or into a
    file inside ox_inventory/data/items/ if your build supports split
    item files).

    The pizza box is a normal stackable inventory item, so players can
    trade it, give it away, or drop it like any other item.
]]

['pizza_box'] = {
    label = 'Pizza Box',
    weight = 800,
    stack = true,
    close = true,
    description = 'A hot, fresh pizza ready for delivery. Could probably be sold on for a decent price too.',
    client = {
        image = 'pizza_box.png'
    }
},
