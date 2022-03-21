import NFTDrop from 0xNFTDrop
import NonFungibleToken from 0xNonFungibleToken
import FungibleToken from 0xFungibleToken
import ClaimNFT from 0xClaimNFT

// Create drop.

transaction(
    name: String, 
    description: String,
    imageURI: String,
    price: UFix64, 
    adminPublicKey: String
) {
    prepare(signer: AuthAccount) {
        // todo: revise
        // drop static paths support only one drop per acct
        assert(!signer.getCapability<&{NFTDrop.DropPublic}>(NFTDrop.DropPublicPath).check(), message: "drop already exists")

        // proposer NFT/ClaimNFT collection 
        let collectionCap = signer.getCapability<&{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>(ClaimNFT.CollectionPrivatePath)

        // proposer FT token vault
        let paymentReceiverCap = signer.getCapability<&{FungibleToken.Receiver}>(/public/flowTokenReceiver)

        // create Drop
        let drop <- NFTDrop.createDrop(
            name: name,
            description: description,
            imageURI: imageURI,
            nftType: Type<@ClaimNFT.NFT>(),
            price: price,
            collectionCap: collectionCap,
            paymentReceiverCap: paymentReceiverCap,
            adminPublicKey: adminPublicKey
        )

        // save Drop to account storage
        signer.save(<- drop, to: NFTDrop.DropStoragePath)
        signer.link<&NFTDrop.Drop{NFTDrop.DropPublic}>(
            NFTDrop.DropPublicPath, 
            target: NFTDrop.DropStoragePath
        )
        signer.link<&NFTDrop.Drop{NFTDrop.DropPrivate}>(
            NFTDrop.DropPrivatePath, 
            target: NFTDrop.DropStoragePath
        )
    }
}