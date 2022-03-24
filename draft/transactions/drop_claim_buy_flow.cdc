import NFTDrop from 0xNFTDrop
import NonFungibleToken from 0xNonFungibleToken
import FungibleToken from 0xFungibleToken
import FlowToken from 0xFlowToken
import ClaimNFT from 0xClaimNFT

// Buy claim from drop.

transaction(
    dropAddress: Address,
    sigClaimIDs: [UInt64], 
    sigExpiration: UFix64, 
    sig: String
) {
    let paymentVault: @FungibleToken.Vault
    let claimCollection: &{NonFungibleToken.CollectionPublic}
    let drop: &{NFTDrop.DropPublic}
    let purchaserAddress: Address

    prepare(signer: AuthAccount) {
        self.purchaserAddress = signer.address

        self.drop = getAccount(dropAddress).getCapability<&{NFTDrop.DropPublic}>(NFTDrop.DropPublicPath).borrow() 
            ?? panic("Cannot borrow Drop")
        let price = self.drop.getPrice() * UFix64(sigClaimIDs.length) // price * count
        let ftVault = signer.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Cannot borrow FlowToken vault from signer storage")
        self.paymentVault <- ftVault.withdraw(amount: price)

        if !signer.getCapability<&{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>(ClaimNFT.CollectionPrivatePath).check() {
            let collection <- ClaimNFT.createEmptyCollection()
            signer.save(<-collection, to: ClaimNFT.CollectionStoragePath)
            signer.link<&ClaimNFT.Collection{NonFungibleToken.CollectionPublic}>(ClaimNFT.CollectionPublicPath, target: ClaimNFT.CollectionStoragePath)
            signer.link<&ClaimNFT.Collection{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>(ClaimNFT.CollectionPrivatePath, target: ClaimNFT.CollectionStoragePath)
            // signer.link<&Collection{IClaimNFT.IClaimNFTCollectionPublic}>(self.IClaimNFTCollectionPublicPath, target: self.CollectionStoragePath)
        }
        self.claimCollection = signer.getCapability<&{NonFungibleToken.CollectionPublic}>(ClaimNFT.CollectionPublicPath).borrow()
            ?? panic("Cannot borrow Claim Collection")
    }

    execute {
        let data = NFTDrop.AdminSignedData(
            dropAddress: dropAddress,
            purchaserAddress: self.purchaserAddress,
            nftIDs: sigClaimIDs, 
            expiration: sigExpiration
        )

        let claims <- self.drop.purchaseNFTs(
            payment: <- self.paymentVault,
            data: data,
            sig: sig
        )


        let claimsCount = claims.length
        var i = 0
        while i < claims.length {
            let claim <- claims.remove(at: 0)
            self.claimCollection.deposit(token: <- claim)
        }
        assert(claims.length == 0, message: "claim(s) weren't deposited into collection")
        destroy claims
    }
}