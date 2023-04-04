module components_common::token_objects_store {
    use std::signer;
    use std::vector;
    use aptos_framework::object::{Self, Object};
    use aptos_framework::type_info::{Self, TypeInfo};
    use components_common::components_common::OwnershipGroup;

    struct ObjectDisplay has store, drop {
        object_address: address,
        toplevel_type: TypeInfo // for example AptosToken
    }

    #[resource_group_member(group = OwnershipGroup)]
    struct TokenObjectsStore has key {
        tokens: vector<ObjectDisplay>
    }

    public fun register(account: &signer) {
        if (!exists<TokenObjectsStore>(signer::address_of(account))) {
            move_to(
                account, 
                TokenObjectsStore{
                    tokens: vector::empty()
                }
            );
        }
    }

    public fun num_holds(owner: address): u64
    acquires TokenObjectsStore {
        if (!exists<TokenObjectsStore>(owner)) {
            0
        } else {
            let holder = borrow_global<TokenObjectsStore>(owner);
            vector::length(&holder.tokens)    
        }
    }

    public fun holds<T: key>(owner: address, object: Object<T>): bool
    acquires TokenObjectsStore {
        if (!exists<TokenObjectsStore>(owner)) {
            return false
        } else {
            let holder = borrow_global<TokenObjectsStore>(owner);
            let display = ObjectDisplay{
                object_address: object::object_address(&object),
                toplevel_type: type_info::type_of<T>()
            };
            vector::contains(&holder.tokens, &display)
        }
    }

    public entry fun update<T: key>(caller: address, object: Object<T>)
    acquires TokenObjectsStore {
        let holder = borrow_global_mut<TokenObjectsStore>(caller);
        let display = ObjectDisplay{
            object_address: object::object_address(&object),
            toplevel_type: type_info::type_of<T>()
        };

        if (object::owns(object, caller)) {
            if (!vector::contains(&holder.tokens, &display)) {
                vector::push_back(&mut holder.tokens, display);
            }
        } else {
            let (ok, idx) = vector::index_of(&holder.tokens, &display);
            if (ok) {
                vector::swap_remove(&mut holder.tokens, idx);
            }
        }
    }

    #[test_only]
    struct TestToken has key {}

    #[test(account = @0x123)] 
    fun test_holder(account: &signer)
    acquires TokenObjectsStore {
        register(account);
        let cctor = object::create_named_object(account, b"testobj");
        let obj_signer = object::generate_signer(&cctor);
        move_to(&obj_signer, TestToken{});
        let obj = object::object_from_constructor_ref<TestToken>(&cctor);
        let addr = signer::address_of(account);
        assert!(
            num_holds(addr) == 0,
            0
        );
        update<TestToken>(addr, obj);
        assert!(
            num_holds(addr) == 1 && holds(addr, obj),
            1
        );
        object::transfer(account, obj, @0x234);
        update<TestToken>(addr, obj);
        assert!(
            num_holds(addr) == 0 && !holds(addr, obj),
            2
        );
    }

    #[test(account = @0x123)] 
    fun test_add_twice(account: &signer)
    acquires TokenObjectsStore {
        register(account);
        let cctor = object::create_named_object(account, b"testobj");
        let obj_signer = object::generate_signer(&cctor);
        move_to(&obj_signer, TestToken{});
        let obj = object::object_from_constructor_ref<TestToken>(&cctor);
        let addr = signer::address_of(account);
        update<TestToken>(addr, obj);
        update<TestToken>(addr, obj);
        assert!(
            num_holds(addr) == 1 && holds(addr, obj),
            1
        );
    }

    #[test(account = @0x123)] 
    fun test_remove_twice(account: &signer)
    acquires TokenObjectsStore {
        register(account);
        let addr = signer::address_of(account);
        let cctor = object::create_named_object(account, b"staticobj");
        let obj_signer = object::generate_signer(&cctor);
        move_to(&obj_signer, TestToken{});
        let obj = object::object_from_constructor_ref<TestToken>(&cctor);
        update<TestToken>(addr, obj);
        let cctor = object::create_named_object(account, b"testobj");
        let obj_signer = object::generate_signer(&cctor);
        move_to(&obj_signer, TestToken{});
        let obj = object::object_from_constructor_ref<TestToken>(&cctor);
        update<TestToken>(addr, obj);
        object::transfer(account, obj, @0x234);
        update<TestToken>(addr, obj);
        update<TestToken>(addr, obj);
        assert!(
            num_holds(addr) == 1 && !holds(addr, obj),
            1
        );
    }    
}