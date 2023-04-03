module components_common::token_objects_store {
    use std::error;
    use std::signer;
    use std::vector;
    use aptos_framework::object::{Self, Object};
    use aptos_framework::type_info::{Self, TypeInfo};

    const E_TOKEN_ALREADY_EXISTS: u64 = 1;
    const E_TOKEN_NOT_EXISTS: u64 = 2;
    const E_HOLDER_NOT_EXISTS: u64 = 3;
    const E_NOT_OWNER: u64 = 4;
    const E_STILL_OWNER: u64 = 5;

    struct ObjectDisplay has store, drop {
        object_address: address,
        toplevel_type: TypeInfo // for example AptosToken
    }

    struct TokenObjectsStore has key {
        tokens: vector<ObjectDisplay>
    }

    public fun register<T: key>(account: &signer) {
        let address = signer::address_of(account);
        if (!exists<TokenObjectsStore>(address)) {
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
            let type = type_info::type_of<T>();
            vector::contains(
                &holder.tokens, 
                &ObjectDisplay{
                    object_address: object::object_address(&object),
                    toplevel_type: type
                }
            )
        }
    } 

    public fun add_to_holder<T: key>(owner: address, object: Object<T>)
    acquires TokenObjectsStore {
        assert!(
            exists<TokenObjectsStore>(owner),
            error::not_found(E_HOLDER_NOT_EXISTS)
        );
        assert!(
            object::is_owner(object, owner),
            error::permission_denied(E_NOT_OWNER)
        );

        let holder = borrow_global_mut<TokenObjectsStore>(owner);
        let display = ObjectDisplay{
            object_address: object::object_address(&object),
            toplevel_type: type_info::type_of<T>()
        };
        if (vector::length(&holder.tokens) != 0) {
            assert!(
                !vector::contains(&holder.tokens, &display),
                error::already_exists(E_TOKEN_ALREADY_EXISTS)
            );
        };
        vector::push_back(&mut holder.tokens, display);
    }

    public fun remove_from_holder<T: key>(owner: address, object: Object<T>)
    acquires TokenObjectsStore {
        assert!(
            exists<TokenObjectsStore>(owner),
            error::not_found(E_HOLDER_NOT_EXISTS)
        );
        assert!(
            !object::is_owner(object, owner),
            error::permission_denied(E_STILL_OWNER)
        );
        
        let holder = borrow_global_mut<TokenObjectsStore>(owner);
        if (vector::length(&holder.tokens) == 0) {
            return
        };

        let display = ObjectDisplay{
            object_address: object::object_address(&object),
            toplevel_type: type_info::type_of<T>()
        };
        let (ok, idx) = vector::index_of(&holder.tokens, &display);
        assert!(
            ok,
            error::not_found(E_TOKEN_NOT_EXISTS)
        );
        _ = vector::swap_remove(&mut holder.tokens, idx);
    }

    #[test_only]
    struct TestToken has key {}

    #[test(account = @0x123)] 
    fun test_holder(account: &signer)
    acquires TokenObjectsStore {
        register<TestToken>(account);
        let cctor = object::create_named_object(account, b"testobj");
        let obj_signer = object::generate_signer(&cctor);
        move_to(&obj_signer, TestToken{});
        let obj = object::object_from_constructor_ref(&cctor);
        let addr = signer::address_of(account);
        assert!(
            num_holds(addr) == 0,
            0
        );
        add_to_holder<TestToken>(addr, obj);
        assert!(
            num_holds(addr) == 1 && holds(addr, obj),
            1
        );
        object::transfer(account, obj, @0x234);
        remove_from_holder<TestToken>(addr, obj);
        assert!(
            num_holds(addr) == 0 && !holds(addr, obj),
            2
        );
    }

    #[test(account = @0x123)] 
    #[expected_failure(
        abort_code = 0x80001,
        location = Self
    )]
    fun test_add_twice(account: &signer)
    acquires TokenObjectsStore {
        register<TestToken>(account);
        let cctor = object::create_named_object(account, b"testobj");
        let obj_signer = object::generate_signer(&cctor);
        move_to(&obj_signer, TestToken{});
        let obj = object::object_from_constructor_ref(&cctor);
        let addr = signer::address_of(account);
        add_to_holder<TestToken>(addr, obj);
        add_to_holder<TestToken>(addr, obj);
    }

    #[test(account = @0x123)] 
    #[expected_failure(
        abort_code = 0x60002,
        location = Self
    )]
    fun test_remove_twice(account: &signer)
    acquires TokenObjectsStore {
        register<TestToken>(account);
        let addr = signer::address_of(account);
        let cctor = object::create_named_object(account, b"staticobj");
        let obj_signer = object::generate_signer(&cctor);
        move_to(&obj_signer, TestToken{});
        let obj = object::object_from_constructor_ref(&cctor);
        add_to_holder<TestToken>(addr, obj);
        let cctor = object::create_named_object(account, b"testobj");
        let obj_signer = object::generate_signer(&cctor);
        move_to(&obj_signer, TestToken{});
        let obj = object::object_from_constructor_ref(&cctor);
        add_to_holder<TestToken>(addr, obj);
        object::transfer(account, obj, @0x234);
        remove_from_holder<TestToken>(addr, obj);
        remove_from_holder<TestToken>(addr, obj);
    }    
}