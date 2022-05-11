import MetadataViews from 0x1d7e57aa55817448
import NFTStorefront from 0x4eb8a10cb9f87357
import Gaia from 0x8b148183c28ff88f

pub struct PurchaseData {
    pub let id: UInt64
    pub let name: String?
    pub let amount: UFix64
    pub let description: String?
    pub let imageURL: String?

    init(id: UInt64, name: String?, amount: UFix64, description: String?, imageURL: String?) {
        self.id = id
        self.name = name
        self.amount = amount
        self.description = description
        self.imageURL = imageURL
    }
}

pub fun main(address: Address, listingResourceID: UInt64): PurchaseData {
    let account = getAccount(address)
    let marketCollectionRef = account
        .getCapability<&NFTStorefront.Storefront{NFTStorefront.StorefrontPublic}>(
            NFTStorefront.StorefrontPublicPath
        )
        .borrow()
        ?? panic("Could not borrow market collection from address")

    let saleItem = marketCollectionRef.borrowListing(listingResourceID: listingResourceID)
        ?? panic("No item with that ID")

    let listingDetails = saleItem.getDetails()!

    let collection = account.getCapability(Gaia.CollectionPublicPath)
        .borrow<&{Gaia.CollectionPublic}>()
        ?? panic("Could not borrow a reference to the collection")

    let nft = collection.borrowGaiaNFT(id: listingDetails.nftID)
        ?? panic("Could not borrow a reference to the nft")

    let metadata = Gaia.getTemplateMetaData(templateID: nft.data.templateID)!

    var img = "https://images.ongaia.com/ipfs/".concat(metadata["img"]!.slice(from: 7, upTo: metadata["img"]!.length))

    return PurchaseData(
        id: listingDetails.nftID,
        name: metadata["title"],
        amount: listingDetails.salePrice,
        description: metadata["description"],
        imageURL: img,
    )
}
