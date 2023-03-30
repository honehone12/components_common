module components_common::components_common {

    use aptos_framework::object::{Self, ConstructorRef, TransferRef, LinearTransferRef};

    #[resource_group(scope = global)]
    struct ComponentGroup {}

    struct TransferKey has store {
        transfer_ref: TransferRef,
        object_address: address
    }

    public fun create_transfer_key(constructor_ref: &ConstructorRef): TransferKey {
        TransferKey{
            transfer_ref: object::generate_transfer_ref(constructor_ref),
            object_address: object::address_from_constructor_ref(constructor_ref)
        }
    }

    public fun object_address(transfer_key: &TransferKey): address {
        transfer_key.object_address
    }

    public fun generate_linear_transfer_ref(transfer_key: &TransferKey): LinearTransferRef {
        object::generate_linear_transfer_ref(&transfer_key.transfer_ref)
    }

    #[test_only]
    public fun destroy_for_test(transfer_key: TransferKey) {
        TransferKey{
            transfer_ref: _,
            object_address: _
        } = transfer_key;
    }
}