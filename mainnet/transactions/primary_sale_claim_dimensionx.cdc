import GaiaPrimarySale from 0x01ddf82c652e36ef
import NonFungibleToken from 0x1d7e57aa55817448
import DimensionX from 0xe3ad6030cbaff1c2
import MetadataViews from 0x1d7e57aa55817448

transaction(
    marketplaceAddress: Address,
    primarySaleAddress: Address,
    primarySaleExternalID: String,
    assetIDs: [UInt64],
    priceType: String,
    expectedPrice: UFix64,
    sigExpiration: UInt64,
    sig: String
) {
    let primarySale: &{GaiaPrimarySale.PrimarySalePublic}
    let receiverCollection: &{NonFungibleToken.CollectionPublic}
    let purchaserAddress: Address

    prepare(signer: AuthAccount) {
        self.purchaserAddress = signer.address

        self.primarySale = getAccount(primarySaleAddress).getCapability<&{GaiaPrimarySale.PrimarySalePublic}>(GaiaPrimarySale.PrimarySalePublicPath).borrow()
            ?? panic("Cannot borrow primary sale")

        // Make sure buyer has an NFT collection
        if signer.getCapability<&{NonFungibleToken.CollectionPublic}>(DimensionX.CollectionPublicPath).borrow() == nil {
            let collection <- DimensionX.createEmptyCollection() as! @DimensionX.Collection
            signer.save(<-collection, to: DimensionX.CollectionStoragePath)
            signer.link<&DimensionX.Collection{NonFungibleToken.CollectionPublic, DimensionX.CollectionPublic, MetadataViews.ResolverCollection}>(
                DimensionX.CollectionPublicPath,
                target: DimensionX.CollectionStoragePath
            )
        }
        self.receiverCollection = signer.getCapability<&{NonFungibleToken.CollectionPublic}>(DimensionX.CollectionPublicPath).borrow()
            ?? panic("Cannot borrow NFT Collection")
    }

    execute {
        let data = GaiaPrimarySale.AdminSignedData(
            externalID: primarySaleExternalID,
            primarySaleAddress: primarySaleAddress,
            purchaserAddress: self.purchaserAddress,
            assetIDs: assetIDs,
            priceType: priceType,
            expiration: sigExpiration
        )

        let nfts <- self.primarySale.claimNFTs(
            data: data,
            sig: sig
        )

        while nfts.length > 0 {
            let nft <- nfts.remove(at: 0)
            self.receiverCollection.deposit(token: <- nft)
        }
        assert(nfts.length == 0, message: "nfts(s) weren't deposited into collection")
        destroy nfts
    }
}
