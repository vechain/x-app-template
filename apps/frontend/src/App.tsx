import { DAppKitProvider } from "@vechain/dapp-kit-react";
import {
  Alert,
  AlertDescription,
  AlertIcon,
  AlertTitle,
  ChakraProvider,
  Container,
  Flex,
  Link
} from "@chakra-ui/react";
import {
  Dropzone,
  Footer,
  InfoCard,
  Instructions,
  Navbar,
  SubmissionModal,
} from "./components";
import { lightTheme } from "./theme";
import { GoogleReCaptchaProvider } from "react-google-recaptcha-v3";

// RECaptcha V3 site key (https://developers.google.com/recaptcha/docs/v3)
const VITE_RECAPTCHA_V3_SITE_KEY = import.meta.env
  .VITE_RECAPTCHA_V3_SITE_KEY as string;

function App() {
  console.log(VITE_RECAPTCHA_V3_SITE_KEY);
  return (
    <GoogleReCaptchaProvider reCaptchaKey={VITE_RECAPTCHA_V3_SITE_KEY}>
      <ChakraProvider theme={lightTheme}>
        <DAppKitProvider
          usePersistence
          requireCertificate={false}
          genesis="test"
          nodeUrl="https://testnet.vechain.org/"
          logLevel={"DEBUG"}
        >
          <Navbar />
          <Flex flex={1}>
            <Container
              mt={{ base: 4, md: 10 }}
              maxW={"container.xl"}
              mb={{ base: 4, md: 10 }}
              display={"flex"}
              flex={1}
              alignItems={"center"}
              justifyContent={"flex-start"}
              flexDirection={"column"}
            >
              <InfoCard />
              <Instructions />
              <Dropzone />
            </Container>
          </Flex>
          <Footer />
          <Alert status='warning'>
            <AlertIcon />
            <AlertTitle>Disclaimer</AlertTitle>
            <AlertDescription>The use case of this template is inspired by the <Link color='teal.500' className="hover:underline text-blue-500" href={"https://www.greencart.vet/"}>GreenCart Dapp</Link>. The code has been built from scratch and does not contain any references to the GreenCart codebase.</AlertDescription>
          </Alert>
          {/* MODALS  */}
          <SubmissionModal />
        </DAppKitProvider>
      </ChakraProvider>
    </GoogleReCaptchaProvider>
  );
}

export default App;
