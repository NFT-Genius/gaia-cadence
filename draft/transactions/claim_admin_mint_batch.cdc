import ClaimNFT from 0xClaimNFT
import IClaimNFT from 0xIClaimNFT
import NonFungibleToken from 0xNonFungibleToken

// Mint claims as type agnostic NFT representations of other - potentially unrevealed - NFTs

transaction(hashes: [String], dropID: UInt64){
    let admin: &{IClaimNFT.IAdmin}
    let collection: &{NonFungibleToken.CollectionPublic}

    prepare(signer: AuthAccount){
        self.admin = signer.getCapability(ClaimNFT.AdminPrivatePath).borrow<&{IClaimNFT.IAdmin}>()
            ?? panic("Cannot borrow Admin resource")

        // Claim Collection init
        if signer.getCapability(ClaimNFT.CollectionPublicPath).borrow<&{NonFungibleToken.CollectionPublic}>() == nil {
            let collection <- ClaimNFT.createEmptyCollection()
            signer.save(<- collection, to: ClaimNFT.CollectionStoragePath)
            signer.link<&ClaimNFT.Collection{NonFungibleToken.CollectionPublic}>(ClaimNFT.CollectionPublicPath, target: ClaimNFT.CollectionStoragePath)
            signer.link<&ClaimNFT.Collection{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>(ClaimNFT.CollectionPrivatePath, target: ClaimNFT.CollectionStoragePath)
            signer.link<&ClaimNFT.Collection{IClaimNFT.IClaimNFTCollectionPublic}>(ClaimNFT.IClaimNFTCollectionPublicPath, target: ClaimNFT.CollectionStoragePath)
        }
        self.collection = signer.getCapability(ClaimNFT.CollectionPublicPath).borrow<&{NonFungibleToken.CollectionPublic}>()
            ?? panic("Cannot borrow Claim NFT collection")
    }

    execute {
        for hash in hashes {
            let nft <- self.admin.mintClaim(
                hash: hash,
                dropID: dropID
            )            
            self.collection.deposit(token: <- nft)
        }
    }
}