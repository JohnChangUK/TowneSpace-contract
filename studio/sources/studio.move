/*
    - This module is the main entry point for the studio.
    - It is responsible for creating collections, minting tokens,
    and composing and decomposing tokens.
    - It is also responsible for transferring tokens.
*/

module townespace::studio {
    use aptos_framework::object::{Self, Object};
    use aptos_token_objects::royalty::{Royalty};
    // use std::error;
    // use std::features;
    use std::option::{Self, Option};
    use std::string::{String};

    use townespace::core::{
        Self, 
        Composable,
        Trait
        };

    // use townespace::events;

    // -------
    // Structs
    // -------

    // --------------
    // Initialization
    // --------------

    // ---------------
    // Entry Functions
    // ---------------
    
    // Create a new collection
    public entry fun create_collection<T: key>(
        creator_signer: &signer,
        description: String,
        max_supply: Option<u64>, // if the collection is set to haved a fixed supply.
        name: String,
        symbol: String,
        royalty: Option<Royalty>,   // TODO get the same in core.move
        uri: String
    ) {
        core::create_collection_internal<T>(
            creator_signer,
            description,
            max_supply,
            name,
            symbol,
            royalty,
            uri
        );
        // TODO: emit collection created event
    }

    // Mint a composable token
    public entry fun mint_token<T: key>(
        creator_signer: &signer,
        collection_name: String,
        description: String,
        type: String,
        name: String,
        num_type: u64,
        uri: String, 
        traits: vector<Object<Trait>>   // TODO: wrap it in option
    ) {
        core::mint_token_internal<T>(
            creator_signer,
            collection_name,
            description,
            type,
            name,
            num_type,
            uri, 
            traits,
            option::none(),
            option::none(),
            option::none()
        );
        
        // TODO: emit composable token minted event
    }

    // TODO: delete collection

    // Burn composable token
    /*
        This will involve decomposing the composable token, 
        transferring all the associated object tokens
        to the owner, and then burning the aptos token.
    */

    // Compose one object
    public entry fun equip_trait(
        owner_signer: &signer,
        composable_object: Object<Composable>,
        trait_object: Object<Trait>,
        new_uri: String // User should not prompt this! It should be generated by the studio.
    ) {
        // TODO: assert input sanitazation 
        core::equip_trait_internal(owner_signer, composable_object, trait_object);
        // Update uri
        update_uri(
            object::object_address(&composable_object),
            new_uri
            );
        // TODO Emit event
    }

    // Decompose one object
    public entry fun unequip_trait(
        owner_signer: &signer,
        composable_object: Object<Composable>,
        trait_object: Object<Trait>,
        new_uri: String // User should not prompt this! It should be generated by the studio.
    ) {
        // TODO: assert input sanitazation 
        // TODO: assert owner
        core::unequip_trait_internal(owner_signer, composable_object, trait_object);
        // Update uri
        update_uri(
            object::object_address(&composable_object), 
            new_uri
            );
        // TODO Emit event
    }

    // TODO: Decompose an entire composable token
    // public entry fun decompose_entire_token(
    //     owner_signer: &signer,
    //     collection_name: String,
    //     composable_object: Object<Composable>,
    //     new_uri: String // User should not prompt this! It should be generated by the studio.
    // ) {
    //     // TODO: assert input sanitazation 
    //     // TODO: iterate through the vector and unequip traits
    //     // core::unequip_trait_internal(owner_signer, composable_object); 
    //     // Update uri
    //     // update_uri(owner_signer, collection_name, composable_token_object, new_uri);
    //     // TODO: events
    // }

    // Directly transfer a token to a user.
    // public entry fun raw_transfer<T: key>(
    //     owner_signer: &signer, 
    //     token_address: address,
    //     new_owner_address: address,
    // ) {
    //     // TODO: assert input sanitazation 
    //     // TODO: core::transfer
    //     // TODO: events
    // }

    // Transfer with a fee function
    // public entry fun transfer_with_fee<T: key>(
    //     owner_signer: &signer,
    //     token_address: address,
    //     new_owner_address: address,
    //     //fee: u64
    // ){
    //     // TODO: assert input sanitazation 
    //     // TODO: core::transfer
    //     // TODO: events
    // }

    // --------
    // Mutators
    // --------
    // Composable Token
    inline fun update_uri(
        composable_object_address: address,
        new_uri: String
    ) {
        // TODO: asserts 
        core::update_uri_internal(
            composable_object_address, 
            new_uri
            );
        // TODO: events
    }

}