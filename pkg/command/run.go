package command

//go:generate mockgen -destination ../mocks/command/run.go -package mockCommand -source ./run.go
import (
	"fmt"
	"os/exec"
	"regexp"

	"github.com/nikhilsbhat/helm-drift/pkg/deviation"
)

// RunKubeDiffCmd runs the kubectl command with all predefined arguments.
func (cmd *command) RunKubeDiffCmd(deviation *deviation.Deviation) (*deviation.Deviation, error) {
	cmd.log.Debugf("environment variables that would be used: %v", cmd.baseCmd.Environ())

	out, err := cmd.baseCmd.CombinedOutput()
	if err != nil {
		if exerr, ok := err.(*exec.ExitError); ok {
			switch exerr.ExitCode() {
			case 1:
				return handleDrift(deviation, string(out), cmd)
			case 2:
				return handleNamespaceNotFound(deviation, string(out), cmd)
			default:
				return deviation, fmt.Errorf("kubectl diff errored with exit code: %d, message: %s", exerr.ExitCode(), string(out))
			}
		}
		return deviation, fmt.Errorf("unexpected error: %w", err)
	}

	cmd.log.Debugf("no diffs found for '%s' with name '%s'", deviation.Kind, deviation.Kind)
	return deviation, nil
}

func handleDrift(deviation *deviation.Deviation, output string, cmd *command) (*deviation.Deviation, error) {
	deviation.HasDrift = true
	deviation.Deviations = output
	cmd.log.Debugf("found diffs for '%s' with name '%s'", deviation.Kind, deviation.Kind)
	return deviation, nil
}

func handleNamespaceNotFound(deviation *deviation.Deviation, output string, cmd *command) (*deviation.Deviation, error) {
	if output != "" && regexp.MustCompile(`Error from server \(NotFound\): namespaces ".*" not found`).MatchString(output) {
		cmd.log.Debugf("namespace not found, call diff function for file '%s'", deviation.ManifestPath)
		diffCmd := exec.Command("diff", "-u", "-N", "/dev/null", deviation.ManifestPath)
		out, err := diffCmd.CombinedOutput()
		if exerr, ok := err.(*exec.ExitError); ok {
			if exerr.ExitCode() == 1 {
				return handleDrift(deviation, string(out), cmd)
			}
			return deviation, fmt.Errorf("diff errored with exit code: %d, message: %s", exerr.ExitCode(), string(out))
		}
		cmd.log.Debugf("no diffs found for '%s' with name '%s'", deviation.Kind, deviation.Kind)
		return deviation, nil
	}
	return deviation, fmt.Errorf("kubectl diff errored with exit code: 2, message: %s", output)
}

func (cmd *command) RunKubeCmd(deviation *deviation.Deviation) ([]byte, error) {
	cmd.log.Debugf("envionment variables that would be used: %v", cmd.baseCmd.Environ())

	out, err := cmd.baseCmd.CombinedOutput()
	if err != nil {
		cmd.log.Errorf("fetching manifests for '%s' with name '%s' errored with: '%s'", deviation.Kind, deviation.Kind, string(out))

		return nil, err
	}

	return out, nil
}
