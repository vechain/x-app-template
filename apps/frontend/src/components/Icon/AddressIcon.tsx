import React from "react";
import { HTMLChakraProps, Img } from "@chakra-ui/react";
import { PicassoUtils } from "@repo/utils";
const { getPicassoImgSrc } = PicassoUtils;

interface IAddressIcon extends HTMLChakraProps<"img"> {
  address: string;
}
export const AddressIcon: React.FC<IAddressIcon> = ({ address, ...props }) => {
  return <Picasso address={address} {...props} />;
};

interface IPicasso extends HTMLChakraProps<"img"> {
  address: string;
}
const Picasso: React.FC<IPicasso> = ({ address, ...props }) => {
  return (
    <Img
      data-cy={`address-icon-${address}`}
      objectFit={"cover"}
      src={getPicassoImgSrc(address)}
      h={"100%"}
      {...props}
    />
  );
};
