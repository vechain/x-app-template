import {
  Alert,
  AlertDescription,
  AlertIcon,
  AlertTitle,
  Container,
  Link,
} from "@chakra-ui/react";

export const Disclaimer = () => {
  return (
    <Alert status="warning">
      <Container maxW={"container.xl"} display={"flex"} flexDirection={"row"}>
        <AlertIcon />
        <AlertTitle fontSize={"sm"}>Disclaimer</AlertTitle>
        <AlertDescription fontSize={"sm"}>
          The use case of this template is inspired by the{" "}
          <Link color="teal.500" href={"https://www.greencart.vet/"}>
            GreenCart Dapp
          </Link>
          . The code has been built from scratch and does not contain any
          references to the GreenCart codebase.
        </AlertDescription>
      </Container>
    </Alert>
  );
};
