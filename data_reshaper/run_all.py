#!/usr/bin/env python
import os


def _parse_args():
    """ Parse command line arguments """

    import argparse

    parser = argparse.ArgumentParser(
        description="Submit scripts to reshape highres BGC output",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )

    # Optional: specify start year
    parser.add_argument(
        "-y",
        "--start-year",
        action="store",
        dest="start_year",
        type=int,
        default=1990,
        help="First year of run to convert to time series",
    )

    # Optional: specify end year
    parser.add_argument(
        "-e",
        "--end-year",
        action="store",
        dest="end_year",
        type=int,
        default=2025,
        help="Last year of run to convert to time series",
    )

    # Optional: specify ensemble member
    parser.add_argument(
        "-m",
        "--ensemble-member",
        action="store",
        dest="ensemble_member",
        type=int,
        default=1,
        help="Suffix of case to convert to time series",
    )

    # Optional: specify component(s) to run
    parser.add_argument(
        "-c",
        "--components",
        action="store",
        dest="components",
        type=str,
        nargs="+",
        default=[
            "cam",
            "cice",
            "clm",
            "pop",
            "rtm",
        ],
        help="Scripts to submit to slurm",
    )

    # Optional: location of DOUT_S_ROOT
    archive_default = os.path.join(
        os.sep, "glade", "scratch", os.environ["USER"], "archive"
    )
    parser.add_argument(
        "-a",
        "--archive-root",
        action="store",
        dest="archive_root",
        type=str,
        default=archive_default,
        help="base of DOUT_S_ROOT",
    )

    # Optional: specify which scripts to run
    parser.add_argument(
        "-s",
        "--scripts",
        action="store",
        dest="scripts",
        type=str,
        nargs="+",
        default=[
            "6hourly.sh",
            "monthly.sh",
            "daily.sh",
            "annual.sh",
        ],
        help="Scripts to submit to slurm",
    )

    # Optional: is this a dry-run? If so, don't submit anything
    parser.add_argument(
        "-d",
        "--dry-run",
        action="store_true",
        dest="dryrun",
        help="If true, do not actually submit job",
    )

    # Optional: By default, slurm will email users when jobs start and finish
    parser.add_argument(
        "--no-mail",
        action="store_false",
        dest="send_mail",
        help="If true, send SLURM emails to {user}@ucar.edu",
    )

    return parser.parse_args()


###################

def launch_jobs(start_year, end_year):
    """
        Function that calls sbatch with correct options
    """
    for component in args.components:
        for script in args.scripts:
            # Only CAM has 6-hour output
            if script == "6hourly.sh" and component != "cam":
                continue
            # Only POP has annual output
            if script == "annual.sh" and component != "pop":
                continue
            # Only run popeco for daily output
            if component == "popeco" and script != "daily.sh":
                continue
            job = f"{script.split('.')[0]}_{component}_{job_portion}_{ens_id}"
            logbase = f"logs/{job}"
            print(f"Submitting {script} for years {start_year} through {end_year} of {case} as {job}...")
            slurm_opts = f"{mail_opt} --job-name {job} --dependency=singleton"
            slurm_opts += f" -o {logbase}.out.%J -e {logbase}.err.%J"
            script_opts = f"{case} {archive_root} {start_year} {end_year} {component}"
            cmd = f"sbatch {slurm_opts} {script} {script_opts}"
            if not args.dryrun:
                # note: the --dependency=singleton option means only one job per job name
                #       Some jobs had been crashing, and I think it was due to temporary
                #       files clobbering each other? But only having one year for each
                #       component / time period seemed to do the trick
                os.system(cmd)
            else:
                print(f"Command to run: {cmd}")

###################

if __name__ == "__main__":
    args = _parse_args()
    # Kind of kludgy method to ensure that both pop.h.nday1 and pop.h.ecosys.nday1
    # are converted to time series: add "popeco" component that daily.sh uses
    if "pop" in args.components and "daily.sh" in args.scripts:
        args.components.append("popeco")
    archive_root = args.archive_root
    mail_opt = (
        f"--mail-type=ALL --mail-user={os.environ['USER']}@ucar.edu"
        if args.send_mail
        else "--mail-type=NONE"
    )

    ens_id = f"{args.ensemble_member:03}"
    if args.start_year < 2006:
        case = f"b.e11.B20TRC5CNBDRD_no_pinatubo.f09_g16.{ens_id}"
        job_portion = "20TR"
        launch_jobs(args.start_year, min(args.end_year, 2005))
    if args.end_year > 2005:
        case = f"b.e11.BRCP85C5CNBDRD_no_pinatubo.f09_g16.{ens_id}"
        job_portion = "RCP"
        launch_jobs(max(2006, args.start_year), args.end_year)
