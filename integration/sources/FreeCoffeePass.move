module integration::free_coffee_pass {
    use std::signer;
    use std::error;
    use std::string::{String, utf8};
    use std::option::{Self, Option};
    use aptos_framework::timestamp;
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::object::{Self, Object, ExtendRef};
    use aptos_token_objects::token;
    use aptos_token_objects::collection::{Self, Collection};
    use aptos_token_objects::royalty;
    use components_common::components_common::{Self, TransferKey};
    use auctionable_token_objects::auctions;
    use sellable_token_objects::instant_sale;
    use tradable_token_objects::tradings;

    const E_NOT_ADMIN: u64 = 1;

    const A_DAY_IN_SECONDS: u64 = 86400; 

    struct Config has key {
        collection_object: Object<Collection>
    }

    #[resource_group_member(group = object::ObjectGroup)]
    struct FreeCoffeePass has key {
        extend_ref: ExtendRef,
        transfer_key: Option<TransferKey>
    }

    fun init_module(admin: &signer) {
        let constructor_ref = collection::create_fixed_collection(
            admin,
            utf8(b"free-coffee-tickets-for-the-shop"),
            1000,
            utf8(b"free-coffee-pass"),
            option::none(),
            utf8(b"url://free-coffee-pass")
        );
        let collection_object = object::object_from_constructor_ref(&constructor_ref);
        move_to(
            admin, 
            Config{
                collection_object
            }
        );
    }

    public entry fun mint(
        admin: &signer,
        description: String,
        name: String,
        uri: String
    )
    acquires Config {
        assert!(signer::address_of(admin) == @integration, error::permission_denied(E_NOT_ADMIN));

        let config = borrow_global<Config>(@integration);
        let collection_obj = config.collection_object;
        let collection_name = collection::name(collection_obj); 
        let constructor_ref = token::create(
            admin,
            collection_name,
            description,
            name,
            option::some(royalty::create(10, 100, @integration)),
            uri
        );

        let obj = object::object_from_constructor_ref(&constructor_ref);
        let extend_ref = object::generate_extend_ref(&constructor_ref);
        auctions::init_for_coin_type<FreeCoffeePass, AptosCoin>(
            &extend_ref,
            obj,
            collection_name,
            name
        );
        instant_sale::init_for_coin_type<FreeCoffeePass, AptosCoin>(
            &extend_ref,
            obj,
            collection_name,
            name
        );
        tradings::init_trading(
            &extend_ref,
            obj,
            collection_name,
            name
        );

        let object_signer = object::generate_signer(&constructor_ref);
        let transfer_key = components_common::create_transfer_key(constructor_ref);
        move_to(
            &object_signer,
            FreeCoffeePass{
                extend_ref,
                transfer_key: option::some(transfer_key)
            }
        );
    }

    public entry fun enable_transfer(object: Object<FreeCoffeePass>) 
    acquires FreeCoffeePass {
        let free_coffee = borrow_global_mut<FreeCoffeePass>(object::object_address(&object));
        components_common::enable_transfer(option::borrow_mut(&mut free_coffee.transfer_key));
    }

    public entry fun disable_transfer(object: Object<FreeCoffeePass>)
    acquires FreeCoffeePass {
        let free_coffee = borrow_global_mut<FreeCoffeePass>(object::object_address(&object));
        components_common::disable_transfer(option::borrow_mut(&mut free_coffee.transfer_key));
    }

    public entry fun start_auction(
        owner: &signer,
        object: Object<FreeCoffeePass>,
        days: u64,
        min_price: u64
    )
    acquires FreeCoffeePass {
        let free_coffee = borrow_global_mut<FreeCoffeePass>(object::object_address(&object));
        let transfer_key = option::extract(&mut free_coffee.transfer_key);
        let expiration_seconds = timestamp::now_seconds() + A_DAY_IN_SECONDS * days;
        auctions::start_auction<FreeCoffeePass, AptosCoin>(
            owner,
            transfer_key,
            object,
            expiration_seconds,
            min_price
        );
    }

    public entry fun end_auction(owner: &signer, object: Object<FreeCoffeePass>)
    acquires FreeCoffeePass {
        let free_coffee = borrow_global_mut<FreeCoffeePass>(object::object_address(&object));
        let transfer_key = auctions::complete<FreeCoffeePass, AptosCoin>(owner, object);
        option::fill(&mut free_coffee.transfer_key, transfer_key);
    }

    public entry fun start_sale(
        owner: &signer,
        object: Object<FreeCoffeePass>,
        price: u64
    )
    acquires FreeCoffeePass {
        let free_coffee = borrow_global_mut<FreeCoffeePass>(object::object_address(&object));
        let transfer_key = option::extract(&mut free_coffee.transfer_key);
        instant_sale::start_sale<FreeCoffeePass, AptosCoin>(
            owner,
            transfer_key,
            object,
            price
        );
    }

    public entry fun end_sale(owner: &signer, object: Object<FreeCoffeePass>)
    acquires FreeCoffeePass {
        let free_coffee = borrow_global_mut<FreeCoffeePass>(object::object_address(&object));
        let transfer_key = instant_sale::freeze_sale<FreeCoffeePass, AptosCoin>(owner, object);
        option::fill(&mut free_coffee.transfer_key, transfer_key);
    }

    public entry fun start_trading(
        owner: &signer,
        object: Object<FreeCoffeePass>,
        matching_collection_names: vector<String>,
        matching_token_names: vector<String>
    )
    acquires FreeCoffeePass {
        let free_coffee = borrow_global_mut<FreeCoffeePass>(object::object_address(&object));
        let transfer_key = option::extract(&mut free_coffee.transfer_key);
        tradings::start_trading(
            owner,
            transfer_key,
            object,
            matching_collection_names,
            matching_token_names
        );
    }

    public entry fun end_trading(owner: &signer, object: Object<FreeCoffeePass>)
    acquires FreeCoffeePass {
        let free_coffee = borrow_global_mut<FreeCoffeePass>(object::object_address(&object));
        let transfer_key = tradings::freeze_trading(owner, object);
        option::fill(&mut free_coffee.transfer_key, transfer_key);
    }
}
