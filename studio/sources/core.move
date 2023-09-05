/*
    - This contract represents the core of the studio.
    - It allows to create collections and mint tokens.
    - tokens logic is built on top of aptos_token.move.
    - A user can create the following:
        - Collections.
        - Object token (oNFT): A token V2 that represents a specific object.
        - Composable token (cNFT): A token V2 that can hold oNFTs inside.
        - <name-token>: A token V2 that can hold oNFTs, cNFTs, and fungible assets.

    TODO: add asserts functions. (one of the asserts: assert the inputed data is not empty - Input Sanitization?)
    TODO: add function to transform a Composable token into an object token.
    TODO: add fungible assets support.
    TODO: add wrap tokenV1 function.
*/
module townespace::core {
    use aptos_framework::object::{Self, Object};
    use aptos_token_objects::aptos_token::{Self, AptosCollection, AptosToken};

    use std::error;
    use std::features;
    use std::signer;
    use std::string::{Self, String};
    use std::vector;

    friend townespace::studio;

    // ------
    // Errors
    // ------

    // ---------
    // Resources
    // ---------
    
    // Storage state for managing Token Collection
    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct TokenCollection has key {
        collection: Object<aptos_token::AptosCollection>,
        name: String,
        symbol: String,
    }

    // Storage state for managing Composable token
    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct ComposableToken has key {
        token: Object<aptos_token::AptosToken>,
        // The object tokens to store in the composable token.
        object_tokens: vector<Object<ObjectToken>>, // TODO: this must be extended to each object type.
    }

    // Storage state for managing Object Token
    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct ObjectToken has key {
        token: Object<aptos_token::AptosToken>,
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    // Storage state for tracking composable token supply.
    struct TokenSupply has key {
        total_supply: u64,
        remaining_supply: u64,
        total_minted: u64,
    }    

    // ------------------
    // Internal Functions
    // ------------------
    
    // Collection
    public fun create_token_collection_internal(
        creator_signer: &signer,
        description: String,
        max_supply: u64,
        name: String,
        symbol: String,
        uri: String,
        mutable_description: bool,
        mutable_royalty: bool,
        mutable_uri: bool,
        mutable_token_description: bool,
        mutable_token_name: bool,
        mutable_token_properties: bool,
        mutable_token_uri: bool,
        tokens_burnable_by_creator: bool,
        tokens_freezable_by_creator: bool,
        royalty_numerator: u64,
        royalty_denominator: u64,
        seed: vector<u8> // used when auid is disabled.
    ): (Object<TokenCollection>, Object<AptosCollection>) {
        let creator_address = signer::address_of(creator_signer);
        assert!(!string::is_empty(&name), 0);
        assert!(!string::is_empty(&symbol), 1);
        assert!(!string::is_empty(&name), 2);
        // TODO: assert name/symbol are not used.
        // Create composable token object.
        // If auid is enabled, create the object with the creator address.
        // Otherwise, create it with the creator address and the seed.
        let constructor_ref = if (features::auids_enabled()) {
            object::create_object(creator_address)
        } else {
            object::create_named_object(creator_signer, seed)
        };
        // Generate the object signer, used to publish a resource under the token object address.
        let object_signer = object::generate_signer(&constructor_ref);
        // Create aptos collection object.
        let aptos_collection_object = aptos_token::create_collection_object(
            creator_signer,
            description,
            max_supply,
            name,
            uri,
            mutable_description,
            mutable_royalty,
            mutable_uri,
            mutable_token_description,
            mutable_token_name,
            mutable_token_properties,
            mutable_token_uri,
            tokens_burnable_by_creator,
            tokens_freezable_by_creator,
            royalty_numerator,
            royalty_denominator,
        );

        move_to(&object_signer, 
                TokenCollection {
                    collection: aptos_collection_object,
                    name: name,
                    symbol: symbol
                    }
                );

        // Return both objects.
        let token_collection_object = object::object_from_constructor_ref(&constructor_ref);
        (token_collection_object, aptos_collection_object)
    }

    // Composable token
    public fun mint_composable_token_internal(
        creator_signer: &signer,
        collection: String,
        description: String,
        name: String,
        uri: String,
        total_supply: u64,
        object_tokens: vector<Object<ObjectToken>>,
        property_keys: vector<String>,
        property_types: vector<String>,
        property_values: vector<vector<u8>>,
        seed: vector<u8> // used when auid is disabled.
    ): (Object<ComposableToken>, Object<AptosToken>) {
        let creator_address = signer::address_of(creator_signer);
        assert!(total_supply > 0, 4);
        assert!(!string::is_empty(&name), 5);
        assert!(!string::is_empty(&uri), 6);
        // Assert property vectors have the same length.
        assert!(vector::length(&property_keys) == vector::length(&property_types), 7);
        // Create composable token object.
        // If auid is enabled, create the object with the creator address.
        // Otherwise, create it with the creator address and the seed.
        let constructor_ref = if (features::auids_enabled()) {
            object::create_object(creator_address)
        } else {
            object::create_named_object(creator_signer, seed)
        };
        
        // Generate the object signer, used to publish a resource under the token object address.
        let object_signer = object::generate_signer(&constructor_ref);
        // Create aptos token object.
        let aptos_token_object = aptos_token::mint_token_object(
            creator_signer,
            collection,
            description,
            name,
            uri,
            property_keys,
            property_types,
            property_values,
        );

        let new_token_supply = TokenSupply {
            total_supply: total_supply,
            remaining_supply: total_supply,
            total_minted: 0,
            //mint_events: object::new_event_handle(&composable_token_object_signer),
        };
        // Initialize token supply and publish it in the composable token object account.
        // Initialize it with object_tokens vector if it exists. Empty otherwise.
        if (vector::length(&object_tokens) == 0) {
            move_to(&object_signer, ComposableToken {
                token: aptos_token_object,
                object_tokens: vector::empty(),
            });
        } else {
            move_to(&object_signer, ComposableToken {
                token: aptos_token_object,
                object_tokens: object_tokens,
            });
            
        };
        move_to(&object_signer, new_token_supply);
        
        // Return both objects.
        let composable_token_object = object::object_from_constructor_ref(&constructor_ref);
        (composable_token_object, aptos_token_object)
    }

    // Object token
    public fun mint_object_token_internal(
        creator_signer: &signer,
        collection: String,
        description: String,
        name: String,
        uri: String,
        property_keys: vector<String>,
        property_types: vector<String>,
        property_values: vector<vector<u8>>,
        composable_token_object: Object<ComposableToken>, // to use for tracking supply
        seed: vector<u8> // used only when auid is disabled
    ): (Object<ObjectToken>, Object<AptosToken>) acquires TokenSupply {
        assert!(!string::is_empty(&name), 5);
        assert!(!string::is_empty(&uri), 6);
        assert!(
            vector::length(&property_keys) == vector::length(&property_types), 7);
        // Assert the composable token exists.
        assert!(exists<ComposableToken>(object::object_address(&composable_token_object)), 8);
        // Create composable token object.
        let creator_address = signer::address_of(creator_signer);
        // If auid is enabled, create the object with the creator address.
        // Otherwise, create it with the creator address and the seed.
        let constructor_ref = if (features::auids_enabled()) {
            object::create_object(creator_address)
        } else {
            object::create_named_object(creator_signer, seed)
        };
        // Generate the object signer, used to publish a resource under the token object address.
        let object_signer = object::generate_signer(&constructor_ref);
        // create object for aptos token
        let aptos_token_object = aptos_token::mint_token_object(
            creator_signer,
            collection,
            description,
            name,
            uri,
            property_keys,
            property_types,
            property_values,
        );
        // TODO event object token created
        // update the token supply; decrement by one
        decrement_token_supply(&composable_token_object/*, object_token_address*/);
        // Get the object token address
        //let object_token_address = object::object_address(&aptos_token_object);

        // Initialize token supply and publish it in the composable token object account.
        // Initialize it with object_tokens vector if it exists. Empty otherwise.
        // new object to move to resource account
        move_to(&object_signer, ObjectToken {
            token: aptos_token_object,
            //mint_events: object::new_event_handle(&object_signer),
        });
        
        // Return both objects.
        let object_token_object = object::object_from_constructor_ref(&constructor_ref);
        (object_token_object, aptos_token_object)
    }

    public(friend) fun compose_object_internal(
        owner: &signer,
        composable_token_object: Object<ComposableToken>,
        object_token_object: Object<ObjectToken>
    ) acquires ComposableToken, ObjectToken {
        // Composable 
        let composable_token = borrow_global_mut<ComposableToken>(object::object_address(&composable_token_object));
        let composable_aptos_token_object = composable_token.token; 
        // Object
        let object_token = borrow_global_mut<ObjectToken>(object::object_address(&object_token_object));
        let object_aptos_token_object = object_token.token;
        // index = vector length
        let index = vector::length(&composable_token.object_tokens);
        // Assert ungated transfer enabled for the object token.
        assert!(object::ungated_transfer_allowed(object_token_object) == true, 10);
        assert!(object::ungated_transfer_allowed(object_aptos_token_object) == true, 10);
        // Transfer the objects: object -> composable  && object_aptos_token -> composable_aptos_token
        object::transfer_to_object(owner, object_aptos_token_object, composable_aptos_token_object);
        object::transfer_to_object(owner, object_token_object, composable_token_object);
        // Freeze transfer objects
        // aptos_token::freeze_transfer(owner, object_token_object); 
        aptos_token::freeze_transfer(owner, object_aptos_token_object);
        // Add the object to the vector
        vector::insert<Object<ObjectToken>>(&mut composable_token.object_tokens, index, object_token_object);
        // object::transfer(owner, composable_aptos_token_object, @townespace); TODO: add this to unit testing, we send object token to the composable token, and we freeze transfer for the object token, we send the composable token to another address, and the object token is transfered with it.
    }

    // TODO: Fast compose function
    /*
        The user can choose two or more trait_tokens to compose,
        this will mint a composable token and transfer the trait_tokens to it.
        The user can later set the properties of the composable token.
    */
    //public entry fun fast_compose(
    //    owner: &signer,
    //    name: String,
    //    uri: String, // User should not prompt this! It should be generated by the studio.
    //    trait_tokens: vector<Object<ObjectToken>>
    //) acquires TokenCollection {
    //    let owner_address = signer::address_of(owner);
    //    let collection = borrow_global_mut<TokenCollection>(owner_address);
    //    mint_composable_token_internal(
    //        owner,
    //        collection.name,
    //        string::utf8(b"fast composed"), // Description
    //        name,
    //        uri,  // TODO: URI must be generated
    //        1,   // Total supply; fast compose don't have supply.
    //        trait_tokens,
    //        vector::empty(),
    //        vector::empty(),
    //        vector::empty()
    //    );
    //}

    public(friend) fun decompose_object_internal(
        owner_signer: &signer,
        composable_token_object: Object<ComposableToken>,
        object_token_object: Object<ObjectToken>
    ) acquires ComposableToken, ObjectToken {
        let owner_address = signer::address_of(owner_signer);
        // composable token
        let composable_token_address = object::object_address(&composable_token_object);
        let composable_token = borrow_global_mut<ComposableToken>(composable_token_address);
        let composable_aptos_token_object = composable_token.token;
        let composable_aptos_token_address = object::object_address(&composable_aptos_token_object);
        // object token
        let object_token_address = object::object_address(&object_token_object);
        let object_token = borrow_global_mut<ObjectToken>(object_token_address);
        let object_aptos_token_object = object_token.token;
        // get the index "i" of the object. Needed for removing object from vector.
        // pattern matching
        let (_, index) = vector::index_of(&composable_token.object_tokens, &object_token_object);
        // assert the object exists in the composable token address
        assert!(object::is_owner(object_token_object, composable_token_address), 8);
        // assert the object aptos token exists in the composable aptos token address
        assert!(object::is_owner(object_aptos_token_object, composable_aptos_token_address), 9);
        // Unfreeze transfer
        aptos_token::unfreeze_transfer(owner_signer, object_aptos_token_object);
        // Transfer both objects
        object::transfer(owner_signer, object_token_object, owner_address);
        object::transfer(owner_signer, object_aptos_token_object, owner_address);
        // Remove the object from the vector
        vector::remove<Object<ObjectToken>>(&mut composable_token.object_tokens, index);
    }

    // TODO: update
    public(friend) fun decompose_entire_token_internal(
        owner_signer: &signer,
        composable_token_object: Object<ComposableToken>
    ) acquires ComposableToken, ObjectToken {
        let composable_token = borrow_global_mut<ComposableToken>(object::object_address(&composable_token_object)); 
        // assert composable token is not empty
        assert!(vector::length(&composable_token.object_tokens) > 0, 9);
        // Iterate through the vector
        let i = 0;
        while (i < vector::length(&composable_token.object_tokens)) {
            // For each object, unfreeze transfer, transfer to owner, remove from vector
            let object = *vector::borrow(&composable_token.object_tokens, i);
            let object_token_address = object::object_address(&object);
            let object_token = borrow_global_mut<ObjectToken>(object_token_address);
            let object_aptos_token = object_token.token;
            aptos_token::unfreeze_transfer(owner_signer, object_aptos_token);
            object::transfer(owner_signer, object_aptos_token, signer::address_of(owner_signer));
            vector::remove<Object<ObjectToken>>(&mut composable_token.object_tokens, i);
        };  
    }

    // Burn composable token
    /*
        This will involve decomposing the composable token, 
        and then burning the aptos token.
    */
    public fun burn_composable_token_internal(
        owner: &signer,
        composable_token_object: Object<ComposableToken>
    ) acquires ComposableToken, ObjectToken {
        // decompose the composable token
        decompose_entire_token_internal(owner, composable_token_object);
        // burn the aptos token
        let composable_token = borrow_global_mut<ComposableToken>(object::object_address(&composable_token_object));
        aptos_token::burn(owner, composable_token.token);
        // TODO: remove the token supply object from global storage
        // TODO: remove the composable token object from global storage
    }

    // Burn object token
    public fun burn_object_token_internal(
        owner: &signer,
        composable_token_object: Object<ComposableToken>,
        object_token_object: Object<ObjectToken>
    ) acquires ObjectToken, TokenSupply {
        let object_token = borrow_global_mut<ObjectToken>(object::object_address(&object_token_object));
        // burn the aptos token
        aptos_token::burn(owner, object_token.token);
        // increment the token supply
        increment_token_supply(&composable_token_object);
        // TODO: remove the object token object from global storage
    }

    // Directly transfer a token to a user.
    public fun raw_transfer_internal<T: key>(
        owner: &signer, 
        token_address: address,
        new_owner_address: address,
    ) {
        // TODO: If token is object_token, assert transfer is unfreezed (object not equiped to composable nft)
        // Transfer
        let token = object::address_to_object<T>(token_address);
        object::transfer(owner, token, new_owner_address);
    }

    // Transfer with a fee function
    public fun transfer_with_fee_internal<T: key>(
        owner: &signer, 
        token_address: address,
        new_owner_address: address,
    ) {
        // TODO: If token is object_token, assert transfer is unfreezed (object not equiped to composable nft)
        
        // Transfer
        let token = object::address_to_object<T>(token_address);
        // TODO: Charge a small fee that will be sent to studio address.
        object::transfer(owner, token, new_owner_address);
    }
    
    // ---------
    // Accessors
    // ---------

    inline fun borrow<T: key>(
        object: Object<T>
        ): &T acquires TokenCollection, ComposableToken, ObjectToken {
            let object_address = object::object_address(&object);
            assert!(
                exists<T>(object_address),
                error::not_found(1),
            );
            borrow_global<T>(object_address)
    }

    #[view]
    public fun get_collection(
        collection_object: Object<TokenCollection>
    ): Object<AptosCollection> acquires TokenCollection {
        borrow<TokenCollection>(collection_object).collection
    }

    #[view]
    public fun get_collection_symbol(
        collection_object: Object<TokenCollection>
    ): String acquires TokenCollection {
        borrow<TokenCollection>(collection_object).symbol
    }

    #[view]
    public fun get_composable_token(
        token_object: Object<ComposableToken>
    ): Object<AptosToken> acquires ComposableToken {
        borrow(token_object).token
    }

    #[view]
    public fun get_object_token(
        token_object: Object<ObjectToken>
    ): Object<AptosToken> acquires ObjectToken {
        borrow(token_object).token
    }

    #[view]
    public fun get_object_token_vector(
        token_object: Object<ComposableToken>
        ): vector<Object<ObjectToken>> acquires ComposableToken {
            borrow<ComposableToken>(token_object).object_tokens  
        }
        
    #[view]
    public fun get_supply(
        composable_token_object: Object<ComposableToken>
    ): u64 acquires TokenSupply {
        //let reference = borrow<ComposableToken>(composable_token_object);
        let token_supply = borrow_global<TokenSupply>(object::object_address(&composable_token_object));
        token_supply.total_supply
    }

    // --------
    // Mutators
    // --------
    
    // Collection

    // Token
    // Change uri
    public(friend) fun set_uri_internal(
        owner: &signer,
        token: Object<ComposableToken>,
        new_uri: String
    ) acquires ComposableToken {
        let token_address = object::object_address(&token);
        let composable_token_object = borrow_global_mut<ComposableToken>(token_address);
        let aptos_token = composable_token_object.token;
        aptos_token::set_uri(owner, aptos_token, new_uri);
    }
    // Token Supply
    // Decrement the remaining supply on each object token minted.
    inline fun decrement_token_supply(
        composable_token_object: &Object<ComposableToken>,
    ) acquires TokenSupply {
        // Get the composable token address
        let composable_token_address = object::object_address(composable_token_object);
        let token_supply = borrow_global_mut<TokenSupply>(composable_token_address);
        assert!(token_supply.remaining_supply > 0, 1000);
        token_supply.remaining_supply = token_supply.remaining_supply - 1;
        token_supply.total_minted = token_supply.total_minted + 1;
        // TODO: event supply updated (store new values with the minted token)
    }

    // Increment the remaining supply on each object token burned.
    inline fun increment_token_supply(
        composable_token_object: &Object<ComposableToken>,
        //minted_token: address
    ) acquires ComposableToken, TokenSupply {
        // Get the composable token address
        let composable_token_address = object::object_address(composable_token_object);
        let token_supply = borrow_global_mut<TokenSupply>(composable_token_address);
        // assert total supply >= remaining supply
        assert!(token_supply.total_supply >= token_supply.remaining_supply, 1001);
        token_supply.remaining_supply = token_supply.remaining_supply + 1;
        // TODO: event supply updated (store new values with the burned token)
    }
}