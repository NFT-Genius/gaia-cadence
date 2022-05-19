import MetadataViews from 0x1d7e57aa55817448
import NFTStorefront from 0x4eb8a10cb9f87357
import DriverzNFT from 0xa039bd7d55a96c0c

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

    let collection = account.getCapability(DriverzNFT.CollectionPublicPath)
        .borrow<&{DriverzNFT.CollectionPublic}>()
        ?? panic("Could not borrow a reference to the collection")

    let nft = collection.borrowDriverzNFT(id: listingDetails.nftID)

    if let view = nft.resolveView(Type<MetadataViews.Display>()) {
        let display = view as! MetadataViews.Display

        var imageURI = display.thumbnail.uri()
        if (imageURI.slice(from: 0, upTo: 7) == "ipfs://") {
            imageURI = "https://images.ongaia.com/ipfs/".concat(imageURI.slice(from: 7, upTo: imageURI.length))
        }

        let purchaseData = PurchaseData(
            id: listingDetails.nftID,
            name: display.name,
            amount: listingDetails.salePrice,
            description: display.description,
            imageURL: imageURI,
        )

        return purchaseData
    }

    panic("No NFT")
}
