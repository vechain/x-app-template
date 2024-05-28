type Props = {
  color: string;
  size: string | number;
};

export const AirdropIcon = ({ color, size }: Props) => {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 180 180"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
    >
      <path
        d="M117.779 37.3918C106.129 29.3218 90.9694 26.5919 76.4494 31.3219C51.7794 39.3519 38.2894 65.8618 46.3194 90.5418C46.3894 90.7518 46.4694 90.9519 46.5394 91.1619L135.849 62.0818"
        stroke={color}
        strokeWidth="4.5"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
      <path
        d="M101.26 121.142C102.71 120.422 112.38 115.932 114.25 119.162C116.63 123.252 105.09 126.992 101.26 128.692C104.22 127.462 117.3 121.672 119.69 126.562C122.85 133.012 105.85 138.202 98.8203 139.332"
        stroke={color}
        strokeWidth="4.5"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
      <path
        d="M108.07 151.392C120.309 151.392 130.23 141.471 130.23 129.232C130.23 116.993 120.309 107.072 108.07 107.072C95.8316 107.072 85.9102 116.993 85.9102 129.232C85.9102 141.471 95.8316 151.392 108.07 151.392Z"
        stroke={color}
        strokeWidth="4.5"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
      <path
        d="M136.1 62.7719L114.08 105.162"
        stroke={color}
        strokeWidth="4.5"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
      <path
        d="M111.919 70.0419L107.609 104.842"
        stroke={color}
        strokeWidth="4.5"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
      <path
        d="M46.7598 91.8618L89.5198 113.162"
        stroke={color}
        strokeWidth="4.5"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
      <path
        d="M70.5801 83.5018L94.55 109.092"
        stroke={color}
        strokeWidth="4.5"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
      <path
        d="M100.889 106.372L91.2891 76.9019"
        stroke={color}
        strokeWidth="4.5"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
};
