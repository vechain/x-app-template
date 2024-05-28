type Props = {
  color: string;
  size: string | number;
};

export const ScanIcon = ({ color, size }: Props) => {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 180 180"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
    >
      <path
        d="M98.39 110.6C91.86 114.86 84.05 117.34 75.67 117.34C52.65 117.34 34 98.68 34 75.67C34 52.66 52.66 34 75.67 34C98.68 34 117.34 52.66 117.34 75.67C117.34 83.72 115.05 91.25 111.09 97.62L133.11 119.64"
        stroke={color}
        strokeWidth="4.5"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
      <path
        d="M48.4199 75.67C48.4199 60.61 60.6199 48.41 75.6799 48.41C80.9499 48.41 85.8699 49.91 90.0399 52.5C93.4499 54.61 96.3499 57.46 98.5299 60.81C101.32 65.08 102.94 70.19 102.94 75.67C102.94 90.73 90.7399 102.93 75.6799 102.93"
        stroke={color}
        strokeWidth="4.5"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
      <path
        d="M143.661 130.18C147.211 133.73 147.211 139.48 143.661 143.03C140.111 146.58 134.361 146.58 130.811 143.03L98.3906 110.61"
        stroke={color}
        strokeWidth="4.5"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
};
