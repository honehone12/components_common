module components_common::components_common {
    use std::error;
    use aptos_framework::object::{Self, ConstructorRef, TransferRef, LinearTransferRef};

    const E_ENABLED_TRNSFER: u64 = 1;

    #[resource_group(scope = global)]
    struct ComponentGroup {}

    struct TransferKey has store {
        transfer_ref: TransferRef,
        object_address: address,
        enabled_transfer: bool
    }

    public fun create_transfer_key(constructor_ref: ConstructorRef): TransferKey {
        let transfer_ref = object::generate_transfer_ref(&constructor_ref);
        object::enable_ungated_transfer(&transfer_ref); 
        TransferKey{
            transfer_ref,
            object_address: object::address_from_constructor_ref(&constructor_ref),
            enabled_transfer: true
        }
    }

    public fun object_address(transfer_key: &TransferKey): address {
        transfer_key.object_address
    }

    public fun generate_linear_transfer_ref(transfer_key: &TransferKey): LinearTransferRef {
        assert!(!transfer_key.enabled_transfer, error::permission_denied(E_ENABLED_TRNSFER));
        object::generate_linear_transfer_ref(&transfer_key.transfer_ref)
    }

    public fun enable_transfer(transfer_key: &mut TransferKey) {
        object::enable_ungated_transfer(&transfer_key.transfer_ref);
        transfer_key.enabled_transfer = true;
    }

    public fun disable_transfer(transfer_key: &mut TransferKey) {
        object::disable_ungated_transfer(&transfer_key.transfer_ref);
        transfer_key.enabled_transfer = false;
    }

    #[test_only]
    public fun destroy_for_test(transfer_key: TransferKey) {
        TransferKey{
            transfer_ref: _,
            object_address: _,
            enabled_transfer: _,
        } = transfer_key;
    }
}